// Package syncsvc implements the authenticated /v1/sync/* endpoints: sync
// state, delta push/pull, snapshot download, chunked resumable uploads with
// snapshot/reset commit, quota accounting and background GC. Blobs are opaque
// to the server except for the 26-byte header it validates (magic, version,
// kind, epoch) so a blob cannot be replayed across accounts, epochs or kinds.
package syncsvc

import (
	"crypto/rand"
	"database/sql"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"

	"github.com/sillygru/wispie/server/internal/auth"
	"github.com/sillygru/wispie/server/internal/config"
	"github.com/sillygru/wispie/server/internal/httpx"
	"github.com/sillygru/wispie/server/internal/ratelimit"
	"github.com/sillygru/wispie/server/internal/store"
)

const (
	blobMagic      = "WSPB"
	blobVersion    = 1
	kindDelta      = 1
	kindSnapshot   = 2
	headerPrefix   = 26 // magic(4)+version(1)+kind(1)+epoch(4)+blob_id(16)
	uploadTTL      = 24 * time.Hour
	snapshotKeep   = time.Hour // keep a superseded snapshot this long
	deltaRetention = 30 * 24 * time.Hour
	spamGrace      = 48 * time.Hour
)

type Service struct {
	Store *store.Store
	Cfg   config.Config
	Now   func() time.Time

	auth   *auth.Service
	syncRL *ratelimit.Limiter
	pushRL *ratelimit.Limiter
	locks  *keyedMutex
}

func New(st *store.Store, cfg config.Config, now func() time.Time, a *auth.Service) *Service {
	if now == nil {
		now = time.Now
	}
	return &Service{
		Store:  st,
		Cfg:    cfg,
		Now:    now,
		auth:   a,
		syncRL: ratelimit.New(cfg.SyncPerMin, time.Minute, cfg.SyncPerMin, now),
		pushRL: ratelimit.New(cfg.DeltaPushPerMin, time.Minute, cfg.DeltaPushPerMin, now),
		locks:  newKeyedMutex(),
	}
}

func (s *Service) Routes(mux *http.ServeMux) {
	h := httpx.Handler
	mux.HandleFunc("GET /v1/sync/state", h(s.guard(false, s.state)))
	mux.HandleFunc("GET /v1/sync/deltas", h(s.guard(false, s.getDeltas)))
	mux.HandleFunc("POST /v1/sync/deltas", h(s.guard(true, s.postDelta)))
	mux.HandleFunc("GET /v1/sync/snapshot", h(s.guard(false, s.getSnapshot)))
	mux.HandleFunc("POST /v1/sync/uploads", h(s.guard(false, s.uploadInit)))
	mux.HandleFunc("PUT /v1/sync/uploads/{id}", h(s.guard(true, s.uploadChunk)))
	mux.HandleFunc("GET /v1/sync/uploads/{id}", h(s.guard(false, s.uploadStatus)))
	mux.HandleFunc("POST /v1/sync/uploads/{id}/commit", h(s.guard(true, s.uploadCommit)))
	mux.HandleFunc("DELETE /v1/sync/uploads/{id}", h(s.guard(false, s.uploadAbort)))
}

func (s *Service) guard(push bool, f func(http.ResponseWriter, *http.Request, auth.Principal) error) func(http.ResponseWriter, *http.Request) error {
	return s.auth.Require(func(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
		if err := allow(s.syncRL, p.AccountID); err != nil {
			return err
		}
		if push {
			if err := allow(s.pushRL, p.AccountID); err != nil {
				return err
			}
		}
		return f(w, r, p)
	})
}

func allow(l *ratelimit.Limiter, key string) error {
	if ok, wait := l.Allow(key); !ok {
		return httpx.RateLimited(wait)
	}
	return nil
}

// ---- small helpers ----

type querier interface {
	QueryRow(string, ...any) *sql.Row
	Query(string, ...any) (*sql.Rows, error)
	Exec(string, ...any) (sql.Result, error)
}

func randHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}

func headMoved(head int64) *httpx.Error {
	return &httpx.Error{Status: 409, Code: "head_moved", Message: "head moved", Extra: map[string]any{"head": head}}
}

func epochChanged(epoch int64) *httpx.Error {
	return &httpx.Error{Status: 412, Code: "epoch_changed", Message: "epoch changed", Extra: map[string]any{"epoch": epoch}}
}

func quotaExceeded() *httpx.Error {
	return httpx.Err(507, "quota_exceeded", "storage quota exceeded")
}

type blobHeader struct {
	kind  byte
	epoch int64
}

func parseHeader(b []byte) (blobHeader, error) {
	if len(b) < headerPrefix {
		return blobHeader{}, httpx.Err(400, "bad_blob", "blob too short")
	}
	if string(b[0:4]) != blobMagic || b[4] != blobVersion {
		return blobHeader{}, httpx.Err(400, "bad_blob", "bad magic or version")
	}
	k := b[5]
	if k != kindDelta && k != kindSnapshot {
		return blobHeader{}, httpx.Err(400, "bad_blob", "bad kind")
	}
	return blobHeader{kind: k, epoch: int64(binary.BigEndian.Uint32(b[6:10]))}, nil
}

func headerFromFile(path string) (blobHeader, error) {
	f, err := os.Open(path)
	if err != nil {
		return blobHeader{}, err
	}
	defer f.Close()
	buf := make([]byte, headerPrefix)
	if _, err := io.ReadFull(f, buf); err != nil {
		return blobHeader{}, httpx.Err(400, "bad_blob", "blob too short")
	}
	return parseHeader(buf)
}

type acctState struct {
	epoch, head, usage int64
}

func (s *Service) account(q querier, id string) (acctState, error) {
	var a acctState
	err := q.QueryRow(`SELECT epoch, head_seq, usage_bytes FROM accounts WHERE id = ?`, id).
		Scan(&a.epoch, &a.head, &a.usage)
	if errors.Is(err, sql.ErrNoRows) {
		return a, httpx.Err(401, "unauthorized", "account not found")
	}
	return a, err
}

type snapRow struct {
	id      string
	baseSeq int64
	size    int64
	file    string
}

// currentSnapshot is the newest snapshot at the account's current epoch.
func (s *Service) currentSnapshot(q querier, id string, epoch int64) (snapRow, bool, error) {
	var sr snapRow
	err := q.QueryRow(`SELECT id, base_seq, size, file FROM snapshots WHERE account_id = ? AND epoch = ? ORDER BY created_at DESC LIMIT 1`, id, epoch).
		Scan(&sr.id, &sr.baseSeq, &sr.size, &sr.file)
	if errors.Is(err, sql.ErrNoRows) {
		return sr, false, nil
	}
	return sr, err == nil, err
}

func (s *Service) recomputeUsage(q querier, id string) error {
	_, err := q.Exec(`UPDATE accounts SET usage_bytes =
		(SELECT COALESCE(SUM(size),0) FROM deltas WHERE account_id = ?1) +
		(SELECT COALESCE(SUM(size),0) FROM snapshots WHERE account_id = ?1)
		WHERE id = ?1`, id)
	return err
}

func (s *Service) blobPath(accountID, file string) string {
	return filepath.Join(s.Store.BlobDir(accountID), file)
}

// ---- state ----

func (s *Service) stateMap(id string) (map[string]any, error) {
	a, err := s.account(s.Store.DB, id)
	if err != nil {
		return nil, err
	}
	snap, has, err := s.currentSnapshot(s.Store.DB, id, a.epoch)
	if err != nil {
		return nil, err
	}
	base := int64(0)
	var snapJSON any
	if has {
		base = snap.baseSeq
		snapJSON = map[string]any{"id": snap.id, "base_seq": snap.baseSeq, "size": snap.size}
	}
	var cnt, bytes int64
	if err := s.Store.DB.QueryRow(`SELECT COUNT(*), COALESCE(SUM(size),0) FROM deltas WHERE account_id = ? AND seq > ?`, id, base).
		Scan(&cnt, &bytes); err != nil {
		return nil, err
	}
	compaction := cnt > 200 || (has && bytes > snap.size)
	return map[string]any{
		"epoch":                  a.epoch,
		"head_seq":               a.head,
		"snapshot":               snapJSON,
		"deltas_since_snapshot":  cnt,
		"bytes_since_snapshot":   bytes,
		"compaction_recommended": compaction,
		"usage_bytes":            a.usage,
		"quota_bytes":            s.Cfg.QuotaBytes,
	}, nil
}

func (s *Service) state(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
	m, err := s.stateMap(p.AccountID)
	if err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, m)
	return nil
}

// ---- delta pull ----

func (s *Service) getDeltas(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
	after := queryInt64(r, "after", 0)
	maxBytes := queryInt(r, "max_bytes", 8<<20)
	if maxBytes < 1 {
		maxBytes = 8 << 20
	}
	if maxBytes > 32<<20 {
		maxBytes = 32 << 20
	}
	a, err := s.account(s.Store.DB, p.AccountID)
	if err != nil {
		return err
	}
	var minSeq sql.NullInt64
	if err := s.Store.DB.QueryRow(`SELECT MIN(seq) FROM deltas WHERE account_id = ?`, p.AccountID).Scan(&minSeq); err != nil {
		return err
	}
	if after >= a.head {
		writeDeltaHeaders(w, a.head, false, 0)
		return nil
	}
	// head > after: ensure the next needed seq is still retained.
	if !minSeq.Valid || minSeq.Int64 > after+1 {
		return httpx.Err(410, "gone", "requested deltas have been compacted; use snapshot")
	}
	rows, err := s.Store.DB.Query(`SELECT seq, size, file FROM deltas WHERE account_id = ? AND seq > ? ORDER BY seq`, p.AccountID, after)
	if err != nil {
		return err
	}
	type frame struct {
		seq, size int64
		file      string
	}
	var frames []frame
	var total, lastSeq int64
	for rows.Next() {
		var f frame
		if err := rows.Scan(&f.seq, &f.size, &f.file); err != nil {
			rows.Close()
			return err
		}
		if len(frames) > 0 && total+12+f.size > int64(maxBytes) {
			break
		}
		frames = append(frames, f)
		total += 12 + f.size
		lastSeq = f.seq
	}
	rows.Close()
	var more bool
	if err := s.Store.DB.QueryRow(`SELECT EXISTS(SELECT 1 FROM deltas WHERE account_id = ? AND seq > ?)`, p.AccountID, lastSeq).Scan(&more); err != nil {
		return err
	}
	w.Header().Set("Content-Length", strconv.FormatInt(total, 10))
	writeDeltaHeaders(w, a.head, more, 200)
	for _, f := range frames {
		var hdr [12]byte
		binary.BigEndian.PutUint64(hdr[0:8], uint64(f.seq))
		binary.BigEndian.PutUint32(hdr[8:12], uint32(f.size))
		if _, err := w.Write(hdr[:]); err != nil {
			return nil
		}
		fh, err := os.Open(s.blobPath(p.AccountID, f.file))
		if err != nil {
			return nil
		}
		_, _ = io.CopyN(w, fh, f.size)
		fh.Close()
	}
	return nil
}

func writeDeltaHeaders(w http.ResponseWriter, head int64, more bool, status int) {
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Wispie-Head", strconv.FormatInt(head, 10))
	if more {
		w.Header().Set("X-Wispie-More", "1")
	} else {
		w.Header().Set("X-Wispie-More", "0")
	}
	if status != 0 {
		w.WriteHeader(status)
	}
}

// ---- delta push ----

func (s *Service) postDelta(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
	reqEpoch, err := headerInt(r, "X-Wispie-Epoch")
	if err != nil {
		return err
	}
	expectHead, err := headerInt(r, "X-Wispie-Expect-Head")
	if err != nil {
		return err
	}
	r.Body = http.MaxBytesReader(w, r.Body, s.Cfg.MaxDeltaBytes)
	body, err := io.ReadAll(r.Body)
	if err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			return httpx.Err(413, "too_large", "delta too large")
		}
		return httpx.Err(400, "bad_request", "could not read body")
	}
	hdr, err := parseHeader(body)
	if err != nil {
		return err
	}
	if hdr.kind != kindDelta {
		return httpx.Err(400, "bad_blob", "not a delta blob")
	}

	unlock := s.locks.lock(p.AccountID)
	defer unlock()

	tx, err := s.Store.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	a, err := s.account(tx, p.AccountID)
	if err != nil {
		return err
	}
	if reqEpoch != a.epoch || hdr.epoch != a.epoch {
		return epochChanged(a.epoch)
	}
	if expectHead != a.head {
		return headMoved(a.head)
	}
	size := int64(len(body))
	if a.usage+size > s.Cfg.QuotaBytes {
		return quotaExceeded()
	}
	seq := a.head + 1
	file := "d_" + randHex(16)
	if err := s.writeBlob(p.AccountID, file, body); err != nil {
		return err
	}
	day := store.Day(s.Now())
	if _, err := tx.Exec(`INSERT INTO deltas(account_id, seq, epoch, size, file, created_day) VALUES(?,?,?,?,?,?)`,
		p.AccountID, seq, a.epoch, size, file, day); err != nil {
		_ = os.Remove(s.blobPath(p.AccountID, file))
		return err
	}
	if _, err := tx.Exec(`UPDATE accounts SET head_seq = ?, usage_bytes = usage_bytes + ?, last_active_day = ? WHERE id = ?`,
		seq, size, day, p.AccountID); err != nil {
		_ = os.Remove(s.blobPath(p.AccountID, file))
		return err
	}
	if err := tx.Commit(); err != nil {
		_ = os.Remove(s.blobPath(p.AccountID, file))
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{"seq": seq})
	return nil
}

func (s *Service) writeBlob(accountID, file string, body []byte) error {
	if err := os.MkdirAll(s.Store.BlobDir(accountID), 0o700); err != nil {
		return err
	}
	return os.WriteFile(s.blobPath(accountID, file), body, 0o600)
}

// ---- snapshot download ----

func (s *Service) getSnapshot(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
	a, err := s.account(s.Store.DB, p.AccountID)
	if err != nil {
		return err
	}
	snap, has, err := s.currentSnapshot(s.Store.DB, p.AccountID, a.epoch)
	if err != nil {
		return err
	}
	if !has {
		return httpx.Err(404, "no_snapshot", "no snapshot available")
	}
	f, err := os.Open(s.blobPath(p.AccountID, snap.file))
	if err != nil {
		return httpx.Err(404, "no_snapshot", "snapshot missing")
	}
	defer f.Close()
	fi, err := f.Stat()
	if err != nil {
		return err
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Wispie-Snapshot-Id", snap.id)
	w.Header().Set("X-Wispie-Base-Seq", strconv.FormatInt(snap.baseSeq, 10))
	w.Header().Set("X-Wispie-Epoch", strconv.FormatInt(a.epoch, 10))
	http.ServeContent(w, r, "", fi.ModTime(), f)
	return nil
}

// ---- uploads ----

func (s *Service) uploadInit(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
	var req struct {
		Kind    string `json:"kind"`
		Size    int64  `json:"size"`
		Epoch   int64  `json:"epoch"`
		BaseSeq int64  `json:"base_seq"`
	}
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	if req.Kind != "snapshot" && req.Kind != "reset" {
		return httpx.Err(400, "bad_request", "kind must be snapshot or reset")
	}
	if req.Size <= 0 || req.BaseSeq < 0 {
		return httpx.Err(400, "bad_request", "invalid size or base_seq")
	}
	a, err := s.account(s.Store.DB, p.AccountID)
	if err != nil {
		return err
	}
	if req.Kind == "snapshot" {
		if req.Epoch != a.epoch {
			return epochChanged(a.epoch)
		}
		if req.BaseSeq > a.head {
			return headMoved(a.head)
		}
		snap, has, err := s.currentSnapshot(s.Store.DB, p.AccountID, a.epoch)
		if err != nil {
			return err
		}
		cur := int64(0)
		if has {
			cur = snap.size
		}
		if a.usage-cur+req.Size > s.Cfg.QuotaBytes {
			return quotaExceeded()
		}
	} else if req.Size > s.Cfg.QuotaBytes { // reset replaces everything
		return quotaExceeded()
	}
	id := randHex(16)
	file := "u_" + id
	if err := s.writeBlob(p.AccountID, file, nil); err != nil {
		return err
	}
	if _, err := s.Store.DB.Exec(`INSERT INTO uploads(id, account_id, kind, epoch, base_seq, size, received, file, expires_at) VALUES(?,?,?,?,?,?,0,?,?)`,
		id, p.AccountID, req.Kind, req.Epoch, req.BaseSeq, req.Size, file, s.Now().Add(uploadTTL).Unix()); err != nil {
		_ = os.Remove(s.blobPath(p.AccountID, file))
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{"upload_id": id, "chunk_bytes": s.Cfg.ChunkBytes})
	return nil
}

type uploadRow struct {
	kind           string
	epoch, baseSeq int64
	size, received int64
	file           string
}

func (s *Service) loadUpload(q querier, id, accountID string) (uploadRow, error) {
	var u uploadRow
	err := q.QueryRow(`SELECT kind, epoch, base_seq, size, received, file FROM uploads WHERE id = ? AND account_id = ?`, id, accountID).
		Scan(&u.kind, &u.epoch, &u.baseSeq, &u.size, &u.received, &u.file)
	if errors.Is(err, sql.ErrNoRows) {
		return u, httpx.Err(404, "not_found", "upload not found")
	}
	return u, err
}

func (s *Service) uploadChunk(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
	id := r.PathValue("id")
	offset := queryInt64(r, "offset", -1)
	if offset < 0 {
		return httpx.Err(400, "bad_request", "offset required")
	}
	r.Body = http.MaxBytesReader(w, r.Body, s.Cfg.ChunkBytes)
	chunk, err := io.ReadAll(r.Body)
	if err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			return httpx.Err(413, "too_large", "chunk too large")
		}
		return httpx.Err(400, "bad_request", "could not read chunk")
	}

	unlock := s.locks.lock(p.AccountID)
	defer unlock()

	u, err := s.loadUpload(s.Store.DB, id, p.AccountID)
	if err != nil {
		return err
	}
	if offset != u.received {
		return &httpx.Error{Status: 409, Code: "offset_mismatch", Message: "offset mismatch", Extra: map[string]any{"received": u.received}}
	}
	if u.received+int64(len(chunk)) > u.size {
		return httpx.Err(413, "too_large", "upload exceeds declared size")
	}
	f, err := os.OpenFile(s.blobPath(p.AccountID, u.file), os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return err
	}
	if _, err := f.Write(chunk); err != nil {
		f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	recv := u.received + int64(len(chunk))
	if _, err := s.Store.DB.Exec(`UPDATE uploads SET received = ? WHERE id = ?`, recv, id); err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{"received": recv})
	return nil
}

func (s *Service) uploadStatus(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
	u, err := s.loadUpload(s.Store.DB, r.PathValue("id"), p.AccountID)
	if err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{"received": u.received})
	return nil
}

func (s *Service) uploadAbort(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
	id := r.PathValue("id")
	u, err := s.loadUpload(s.Store.DB, id, p.AccountID)
	if err != nil {
		return err
	}
	if _, err := s.Store.DB.Exec(`DELETE FROM uploads WHERE id = ? AND account_id = ?`, id, p.AccountID); err != nil {
		return err
	}
	_ = os.Remove(s.blobPath(p.AccountID, u.file))
	w.WriteHeader(http.StatusNoContent)
	return nil
}

func (s *Service) uploadCommit(w http.ResponseWriter, r *http.Request, p auth.Principal) error {
	id := r.PathValue("id")

	unlock := s.locks.lock(p.AccountID)
	defer unlock()

	u, err := s.loadUpload(s.Store.DB, id, p.AccountID)
	if err != nil {
		return err
	}
	if u.received != u.size {
		return httpx.Err(400, "incomplete", "upload not fully received")
	}
	hdr, err := headerFromFile(s.blobPath(p.AccountID, u.file))
	if err != nil {
		return err
	}
	if hdr.kind != kindSnapshot {
		return httpx.Err(400, "bad_blob", "not a snapshot blob")
	}
	tx, err := s.Store.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	a, err := s.account(tx, p.AccountID)
	if err != nil {
		return err
	}
	snapID := randHex(16)
	finalFile := "s_" + snapID
	day := store.Day(s.Now())
	var staleFiles []string

	if u.kind == "snapshot" {
		if u.epoch != a.epoch || hdr.epoch != a.epoch {
			return epochChanged(a.epoch)
		}
		if u.baseSeq > a.head {
			return headMoved(a.head)
		}
		if _, err := tx.Exec(`INSERT INTO snapshots(account_id, id, epoch, base_seq, size, file, created_day, created_at) VALUES(?,?,?,?,?,?,?,?)`,
			p.AccountID, snapID, a.epoch, u.baseSeq, u.size, finalFile, day, s.Now().Unix()); err != nil {
			return err
		}
	} else { // reset: atomic epoch bump + wipe
		newEpoch := a.epoch + 1
		if hdr.epoch != newEpoch {
			return epochChanged(a.epoch)
		}
		staleFiles, err = s.collectBlobFiles(tx, p.AccountID)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(`DELETE FROM deltas WHERE account_id = ?`, p.AccountID); err != nil {
			return err
		}
		if _, err := tx.Exec(`DELETE FROM snapshots WHERE account_id = ?`, p.AccountID); err != nil {
			return err
		}
		if _, err := tx.Exec(`UPDATE accounts SET epoch = ?, head_seq = 0 WHERE id = ?`, newEpoch, p.AccountID); err != nil {
			return err
		}
		if _, err := tx.Exec(`INSERT INTO snapshots(account_id, id, epoch, base_seq, size, file, created_day, created_at) VALUES(?,?,?,0,?,?,?,?)`,
			p.AccountID, snapID, newEpoch, u.size, finalFile, day, s.Now().Unix()); err != nil {
			return err
		}
	}
	if _, err := tx.Exec(`DELETE FROM uploads WHERE id = ?`, id); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE accounts SET last_active_day = ? WHERE id = ?`, day, p.AccountID); err != nil {
		return err
	}
	// Rename the uploaded file into place before committing so a crash can't
	// leave a committed row pointing at a missing file.
	if err := os.Rename(s.blobPath(p.AccountID, u.file), s.blobPath(p.AccountID, finalFile)); err != nil {
		return err
	}
	if err := s.recomputeUsage(tx, p.AccountID); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		_ = os.Rename(s.blobPath(p.AccountID, finalFile), s.blobPath(p.AccountID, u.file))
		return err
	}
	for _, f := range staleFiles {
		_ = os.Remove(s.blobPath(p.AccountID, f))
	}
	m, err := s.stateMap(p.AccountID)
	if err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, m)
	return nil
}

func (s *Service) collectBlobFiles(q querier, accountID string) ([]string, error) {
	var files []string
	for _, tbl := range []string{"deltas", "snapshots"} {
		rows, err := q.Query(`SELECT file FROM `+tbl+` WHERE account_id = ?`, accountID)
		if err != nil {
			return nil, err
		}
		for rows.Next() {
			var f string
			if err := rows.Scan(&f); err != nil {
				rows.Close()
				return nil, err
			}
			files = append(files, f)
		}
		rows.Close()
	}
	return files, nil
}

// ---- GC ----

// GC runs periodic cleanup: stale uploads, superseded snapshots, compacted
// deltas, spam (never-uploaded) accounts and optionally inactive accounts.
func (s *Service) GC(now time.Time) error {
	if err := s.Store.CleanupExpired(now); err != nil {
		return err
	}
	if err := s.gcUploads(now); err != nil {
		return err
	}
	if err := s.gcSnapshots(now); err != nil {
		return err
	}
	if err := s.gcDeltas(now); err != nil {
		return err
	}
	return s.gcAccounts(now)
}

func (s *Service) gcUploads(now time.Time) error {
	rows, err := s.Store.DB.Query(`SELECT id, account_id, file FROM uploads WHERE expires_at < ?`, now.Unix())
	if err != nil {
		return err
	}
	type up struct{ id, acct, file string }
	var ups []up
	for rows.Next() {
		var u up
		if err := rows.Scan(&u.id, &u.acct, &u.file); err != nil {
			rows.Close()
			return err
		}
		ups = append(ups, u)
	}
	rows.Close()
	for _, u := range ups {
		if _, err := s.Store.DB.Exec(`DELETE FROM uploads WHERE id = ?`, u.id); err != nil {
			return err
		}
		_ = os.Remove(s.blobPath(u.acct, u.file))
	}
	return nil
}

// gcSnapshots removes superseded snapshots (not the newest per account) once
// they are older than snapshotKeep, so in-flight downloads can finish.
func (s *Service) gcSnapshots(now time.Time) error {
	cutoff := now.Add(-snapshotKeep).Unix()
	rows, err := s.Store.DB.Query(`SELECT account_id, id, file, created_at FROM snapshots ORDER BY account_id, created_at DESC`)
	if err != nil {
		return err
	}
	type victim struct{ acct, id, file string }
	var victims []victim
	var seen string
	for rows.Next() {
		var acct, id, file string
		var createdAt int64
		if err := rows.Scan(&acct, &id, &file, &createdAt); err != nil {
			rows.Close()
			return err
		}
		if acct != seen {
			seen = acct // newest for this account: keep
			continue
		}
		if createdAt < cutoff {
			victims = append(victims, victim{acct, id, file})
		}
	}
	rows.Close()
	for _, v := range victims {
		if _, err := s.Store.DB.Exec(`DELETE FROM snapshots WHERE account_id = ? AND id = ?`, v.acct, v.id); err != nil {
			return err
		}
		_ = os.Remove(s.blobPath(v.acct, v.file))
		if err := s.recomputeUsage(s.Store.DB, v.acct); err != nil {
			return err
		}
	}
	return nil
}

// gcDeltas removes deltas at or below the current snapshot base that are older
// than the retention window. Deltas with seq > base_seq are always kept.
func (s *Service) gcDeltas(now time.Time) error {
	cutoffDay := store.Day(now.Add(-deltaRetention))
	rows, err := s.Store.DB.Query(`SELECT d.account_id, d.seq, d.file FROM deltas d
		WHERE d.created_day < ?
		AND d.seq <= COALESCE((SELECT MAX(sn.base_seq) FROM snapshots sn
			JOIN accounts a ON a.id = sn.account_id AND a.epoch = sn.epoch
			WHERE sn.account_id = d.account_id), -1)`, cutoffDay)
	if err != nil {
		return err
	}
	type victim struct {
		acct, file string
		seq        int64
	}
	var victims []victim
	acctSet := map[string]bool{}
	for rows.Next() {
		var v victim
		if err := rows.Scan(&v.acct, &v.seq, &v.file); err != nil {
			rows.Close()
			return err
		}
		victims = append(victims, v)
		acctSet[v.acct] = true
	}
	rows.Close()
	for _, v := range victims {
		if _, err := s.Store.DB.Exec(`DELETE FROM deltas WHERE account_id = ? AND seq = ?`, v.acct, v.seq); err != nil {
			return err
		}
		_ = os.Remove(s.blobPath(v.acct, v.file))
	}
	for acct := range acctSet {
		if err := s.recomputeUsage(s.Store.DB, acct); err != nil {
			return err
		}
	}
	return nil
}

func (s *Service) gcAccounts(now time.Time) error {
	day := store.Day(now)
	// Spam: registered but never uploaded anything within the grace window.
	graceDay := store.Day(now.Add(-spamGrace))
	var ids []string
	rows, err := s.Store.DB.Query(`SELECT id FROM accounts WHERE created_day <= ? AND head_seq = 0
		AND id NOT IN (SELECT account_id FROM snapshots)`, graceDay)
	if err != nil {
		return err
	}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return err
		}
		ids = append(ids, id)
	}
	rows.Close()
	if s.Cfg.InactiveDays > 0 {
		r2, err := s.Store.DB.Query(`SELECT id FROM accounts WHERE last_active_day < ?`, day-int64(s.Cfg.InactiveDays))
		if err != nil {
			return err
		}
		for r2.Next() {
			var id string
			if err := r2.Scan(&id); err != nil {
				r2.Close()
				return err
			}
			ids = append(ids, id)
		}
		r2.Close()
	}
	for _, id := range ids {
		if err := s.Store.DeleteAccount(id); err != nil {
			return err
		}
	}
	return nil
}

// ---- request parsing ----

func queryInt(r *http.Request, key string, def int) int {
	if v := r.URL.Query().Get(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			return n
		}
	}
	return def
}

func queryInt64(r *http.Request, key string, def int64) int64 {
	if v := r.URL.Query().Get(key); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil && n >= 0 {
			return n
		}
	}
	return def
}

func headerInt(r *http.Request, key string) (int64, error) {
	v := r.Header.Get(key)
	if v == "" {
		return 0, httpx.Err(400, "bad_request", "missing header "+key)
	}
	n, err := strconv.ParseInt(v, 10, 64)
	if err != nil || n < 0 {
		return 0, httpx.Err(400, "bad_request", "invalid header "+key)
	}
	return n, nil
}

// ---- per-account serialization ----

type keyedMutex struct {
	mu sync.Mutex
	m  map[string]*entry
}

type entry struct {
	mu  sync.Mutex
	ref int
}

func newKeyedMutex() *keyedMutex { return &keyedMutex{m: map[string]*entry{}} }

func (k *keyedMutex) lock(key string) func() {
	k.mu.Lock()
	e := k.m[key]
	if e == nil {
		e = &entry{}
		k.m[key] = e
	}
	e.ref++
	k.mu.Unlock()
	e.mu.Lock()
	return func() {
		e.mu.Unlock()
		k.mu.Lock()
		e.ref--
		if e.ref == 0 {
			delete(k.m, key)
		}
		k.mu.Unlock()
	}
}
