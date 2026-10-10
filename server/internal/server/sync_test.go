package server

import (
	"bytes"
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/sillygru/wispie/server/internal/config"
)

const (
	kindDelta    = 1
	kindSnapshot = 2
)

func blob(kind byte, epoch int64, payload []byte) []byte {
	b := make([]byte, 26)
	copy(b[0:4], "WSPB")
	b[4] = 1
	b[5] = kind
	binary.BigEndian.PutUint32(b[6:10], uint32(epoch))
	_, _ = rand.Read(b[10:26])
	return append(b, payload...)
}

// raw performs a request with an arbitrary (possibly binary) body and headers.
func (e *env) raw(method, path, token string, body []byte, hdr map[string]string) *httptest.ResponseRecorder {
	e.t.Helper()
	req := httptest.NewRequest(method, path, bytes.NewReader(body))
	req.RemoteAddr = "203.0.113.7:4444"
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	for k, v := range hdr {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	return rec
}

func (e *env) state(a acct) map[string]any {
	e.t.Helper()
	r := e.do("GET", "/v1/sync/state", a.access, nil)
	if r.code != 200 {
		e.t.Fatalf("state: %d %v", r.code, r.body)
	}
	return r.body
}

func epochOf(m map[string]any) int64 { f, _ := m["epoch"].(float64); return int64(f) }
func headOf(m map[string]any) int64  { f, _ := m["head_seq"].(float64); return int64(f) }

// pushDelta posts a delta at the account's current epoch/head, returns seq.
func (e *env) pushDelta(a acct, payload []byte) *httptest.ResponseRecorder {
	st := e.state(a)
	return e.raw("POST", "/v1/sync/deltas", a.access, blob(kindDelta, epochOf(st), payload), map[string]string{
		"X-Wispie-Epoch":       fmt.Sprint(epochOf(st)),
		"X-Wispie-Expect-Head": fmt.Sprint(headOf(st)),
	})
}

// resetUpload installs a fresh snapshot via the reset path, bumping the epoch.
func (e *env) resetUpload(a acct, payload []byte) map[string]any {
	e.t.Helper()
	st := e.state(a)
	newEpoch := epochOf(st) + 1
	data := blob(kindSnapshot, newEpoch, payload)
	init := e.do("POST", "/v1/sync/uploads", a.access, map[string]any{
		"kind": "reset", "size": len(data), "epoch": newEpoch, "base_seq": 0,
	})
	if init.code != 200 {
		e.t.Fatalf("reset init: %d %v", init.code, init.body)
	}
	id := str(init.body, "upload_id")
	if r := e.raw("PUT", "/v1/sync/uploads/"+id+"?offset=0", a.access, data, nil); r.Code != 200 {
		e.t.Fatalf("reset chunk: %d", r.Code)
	}
	r := e.do("POST", "/v1/sync/uploads/"+id+"/commit", a.access, nil)
	if r.code != 200 {
		e.t.Fatalf("reset commit: %d %v", r.code, r.body)
	}
	return r.body
}

func TestSyncDeltaRoundTrip(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("alice")
	e.resetUpload(a, []byte("snap"))
	for i := 0; i < 3; i++ {
		if r := e.pushDelta(a, []byte{byte(i)}); r.Code != 200 {
			t.Fatalf("push %d: %d %s", i, r.Code, r.Body)
		}
	}
	st := e.state(a)
	if headOf(st) != 3 {
		t.Fatalf("head: %v", st)
	}
	r := e.raw("GET", "/v1/sync/deltas?after=0", a.access, nil, nil)
	if r.Code != 200 || r.Header().Get("X-Wispie-Head") != "3" || r.Header().Get("X-Wispie-More") != "0" {
		t.Fatalf("deltas: %d %v", r.Code, r.Header())
	}
	// Parse frames back out.
	body := r.Body.Bytes()
	var seqs []int64
	for len(body) > 0 {
		seq := int64(binary.BigEndian.Uint64(body[0:8]))
		n := binary.BigEndian.Uint32(body[8:12])
		seqs = append(seqs, seq)
		body = body[12+int(n):]
	}
	if len(seqs) != 3 || seqs[0] != 1 || seqs[2] != 3 {
		t.Fatalf("frames: %v", seqs)
	}
}

func TestSyncConcurrentPushesUniqueSeqs(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("bob")
	e.resetUpload(a, []byte("snap"))
	const n = 20
	var wg sync.WaitGroup
	codes := make([]int, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			codes[i] = e.pushDelta(a, []byte{byte(i)}).Code
		}(i)
	}
	wg.Wait()
	ok := 0
	for _, c := range codes {
		if c == 200 {
			ok++
		} else if c != 409 {
			t.Fatalf("unexpected code %d", c)
		}
	}
	if ok == 0 {
		t.Fatal("no pushes succeeded")
	}
	// Head equals number of successes; seqs are a contiguous 1..head range.
	if got := headOf(e.state(a)); got != int64(ok) {
		t.Fatalf("head %d != successes %d", got, ok)
	}
	r := e.raw("GET", "/v1/sync/deltas?after=0", a.access, nil, nil)
	body := r.Body.Bytes()
	seen := map[int64]bool{}
	var last int64
	for len(body) > 0 {
		seq := int64(binary.BigEndian.Uint64(body[0:8]))
		n := binary.BigEndian.Uint32(body[8:12])
		if seen[seq] {
			t.Fatalf("duplicate seq %d", seq)
		}
		seen[seq] = true
		if seq != last+1 {
			t.Fatalf("non-monotonic: %d after %d", seq, last)
		}
		last = seq
		body = body[12+int(n):]
	}
}

func TestSyncPushConflicts(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("carol")
	e.resetUpload(a, []byte("snap"))
	st := e.state(a)
	ep, head := epochOf(st), headOf(st)
	// Wrong expect-head -> 409.
	r := e.raw("POST", "/v1/sync/deltas", a.access, blob(kindDelta, ep, []byte("x")), map[string]string{
		"X-Wispie-Epoch": fmt.Sprint(ep), "X-Wispie-Expect-Head": fmt.Sprint(head + 5),
	})
	if r.Code != 409 {
		t.Fatalf("head conflict: %d", r.Code)
	}
	// Wrong epoch -> 412.
	r = e.raw("POST", "/v1/sync/deltas", a.access, blob(kindDelta, ep+1, []byte("x")), map[string]string{
		"X-Wispie-Epoch": fmt.Sprint(ep + 1), "X-Wispie-Expect-Head": fmt.Sprint(head),
	})
	if r.Code != 412 {
		t.Fatalf("epoch conflict: %d", r.Code)
	}
	// Wrong kind in blob -> 400.
	r = e.raw("POST", "/v1/sync/deltas", a.access, blob(kindSnapshot, ep, []byte("x")), map[string]string{
		"X-Wispie-Epoch": fmt.Sprint(ep), "X-Wispie-Expect-Head": fmt.Sprint(head),
	})
	if r.Code != 400 {
		t.Fatalf("kind mismatch: %d", r.Code)
	}
}

func TestSyncDeltaTooLarge(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("dan")
	e.resetUpload(a, []byte("snap"))
	st := e.state(a)
	big := make([]byte, e.cfg.MaxDeltaBytes+100)
	r := e.raw("POST", "/v1/sync/deltas", a.access, append(blob(kindDelta, epochOf(st), nil), big...), map[string]string{
		"X-Wispie-Epoch": fmt.Sprint(epochOf(st)), "X-Wispie-Expect-Head": fmt.Sprint(headOf(st)),
	})
	if r.Code != 413 {
		t.Fatalf("too large: %d", r.Code)
	}
}

func TestSyncQuota(t *testing.T) {
	e := newEnv(t, func(c *config.Config) { c.QuotaBytes = 2000 })
	a := e.register("erin")
	// Upload init over quota -> 507.
	if r := e.do("POST", "/v1/sync/uploads", a.access, map[string]any{"kind": "reset", "size": 5000, "epoch": 1, "base_seq": 0}); r.code != 507 {
		t.Fatalf("init quota: %d %v", r.code, r.body)
	}
	e.resetUpload(a, make([]byte, 1500))
	// Now a delta that would exceed quota -> 507.
	st := e.state(a)
	payload := make([]byte, 1000)
	r := e.raw("POST", "/v1/sync/deltas", a.access, append(blob(kindDelta, epochOf(st), nil), payload...), map[string]string{
		"X-Wispie-Epoch": fmt.Sprint(epochOf(st)), "X-Wispie-Expect-Head": fmt.Sprint(headOf(st)),
	})
	if r.Code != 507 {
		t.Fatalf("delta quota: %d", r.Code)
	}
}

func TestSyncResetWipesAndBumpsEpoch(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("fred")
	e.resetUpload(a, []byte("snap1"))
	e.pushDelta(a, []byte("d1"))
	e.pushDelta(a, []byte("d2"))
	before := e.state(a)
	m := e.resetUpload(a, []byte("snap2"))
	if epochOf(m) != epochOf(before)+1 {
		t.Fatalf("epoch not bumped: %v -> %v", before, m)
	}
	if headOf(m) != 0 {
		t.Fatalf("head not reset: %v", m)
	}
	// Old deltas are gone: nothing to pull at the new epoch's empty head.
	if r := e.raw("GET", "/v1/sync/deltas?after=0", a.access, nil, nil); r.Code != 200 || r.Body.Len() != 0 {
		t.Fatalf("expected empty deltas after reset: %d len=%d", r.Code, r.Body.Len())
	}
	// The new snapshot is served at the bumped epoch.
	if r := e.raw("GET", "/v1/sync/snapshot", a.access, nil, nil); r.Code != 200 || r.Header().Get("X-Wispie-Epoch") != fmt.Sprint(epochOf(m)) {
		t.Fatalf("snapshot epoch: %d %v", r.Code, r.Header())
	}
}

func TestSyncUploadResume(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("gail")
	data := blob(kindSnapshot, 1, make([]byte, 100))
	init := e.do("POST", "/v1/sync/uploads", a.access, map[string]any{"kind": "reset", "size": len(data), "epoch": 1, "base_seq": 0})
	id := str(init.body, "upload_id")
	// First chunk.
	if r := e.raw("PUT", "/v1/sync/uploads/"+id+"?offset=0", a.access, data[:40], nil); r.Code != 200 {
		t.Fatalf("chunk1: %d", r.Code)
	}
	// Wrong offset -> 409 with received.
	if r := e.raw("PUT", "/v1/sync/uploads/"+id+"?offset=10", a.access, data[40:], nil); r.Code != 409 {
		t.Fatalf("offset mismatch: %d", r.Code)
	}
	// Status reports progress for resume.
	if r := e.do("GET", "/v1/sync/uploads/"+id, a.access, nil); r.code != 200 || int(r.body["received"].(float64)) != 40 {
		t.Fatalf("status: %d %v", r.code, r.body)
	}
	// Resume from the correct offset and commit.
	if r := e.raw("PUT", "/v1/sync/uploads/"+id+"?offset=40", a.access, data[40:], nil); r.Code != 200 {
		t.Fatalf("resume: %d", r.Code)
	}
	if r := e.do("POST", "/v1/sync/uploads/"+id+"/commit", a.access, nil); r.code != 200 {
		t.Fatalf("commit: %d %v", r.code, r.body)
	}
}

func TestSyncSnapshotDownloadRange(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("hugo")
	payload := bytes.Repeat([]byte("Z"), 200)
	e.resetUpload(a, payload)
	full := e.raw("GET", "/v1/sync/snapshot", a.access, nil, nil)
	if full.Code != 200 || full.Header().Get("X-Wispie-Epoch") != "1" {
		t.Fatalf("snapshot: %d %v", full.Code, full.Header())
	}
	whole := full.Body.Bytes()
	part := e.raw("GET", "/v1/sync/snapshot", a.access, nil, map[string]string{"Range": "bytes=10-19"})
	if part.Code != http.StatusPartialContent || !bytes.Equal(part.Body.Bytes(), whole[10:20]) {
		t.Fatalf("range: %d len=%d", part.Code, part.Body.Len())
	}
}

func TestSyncGCRetainsLiveDeltas(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("ivy")
	e.resetUpload(a, []byte("snap"))
	e.pushDelta(a, []byte("d1")) // seq 1
	e.pushDelta(a, []byte("d2")) // seq 2
	// Install a snapshot at base_seq=1 so seq<=1 becomes compactable.
	st := e.state(a)
	data := blob(kindSnapshot, epochOf(st), []byte("snap2"))
	init := e.do("POST", "/v1/sync/uploads", a.access, map[string]any{"kind": "snapshot", "size": len(data), "epoch": epochOf(st), "base_seq": 1})
	id := str(init.body, "upload_id")
	e.raw("PUT", "/v1/sync/uploads/"+id+"?offset=0", a.access, data, nil)
	if r := e.do("POST", "/v1/sync/uploads/"+id+"/commit", a.access, nil); r.code != 200 {
		t.Fatalf("snap commit: %d %v", r.code, r.body)
	}
	// Advance well past retention, then GC. Refresh the (now expired) access token.
	e.clk.Add(40 * 24 * time.Hour)
	if err := e.srv.Sync.GC(e.clk.Now()); err != nil {
		t.Fatal(err)
	}
	rf := e.do("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": a.refresh})
	a.access = str(rf.body, "access_token")
	// seq 1 (<= base_seq, old) gone; seq 2 (> base_seq) retained.
	r := e.raw("GET", "/v1/sync/deltas?after=1", a.access, nil, nil)
	if r.Code != 200 {
		t.Fatalf("pull after base: %d", r.Code)
	}
	body := r.Body.Bytes()
	if len(body) == 0 {
		t.Fatal("seq 2 should be retained")
	}
	seq := int64(binary.BigEndian.Uint64(body[0:8]))
	if seq != 2 {
		t.Fatalf("expected seq 2, got %d", seq)
	}
	// Pulling from before the retained range must 410.
	if r := e.raw("GET", "/v1/sync/deltas?after=0", a.access, nil, nil); r.Code != 410 {
		t.Fatalf("expected 410 below retained: %d", r.Code)
	}
}

func TestSyncUploadAbortRemovesFile(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("jack")
	data := blob(kindSnapshot, 1, make([]byte, 50))
	init := e.do("POST", "/v1/sync/uploads", a.access, map[string]any{"kind": "reset", "size": len(data), "epoch": 1, "base_seq": 0})
	id := str(init.body, "upload_id")
	e.raw("PUT", "/v1/sync/uploads/"+id+"?offset=0", a.access, data, nil)
	dir := e.st.BlobDir(a.id)
	before, _ := os.ReadDir(dir)
	if len(before) == 0 {
		t.Fatal("expected upload file")
	}
	if r := e.do("DELETE", "/v1/sync/uploads/"+id, a.access, nil); r.code != 204 {
		t.Fatalf("abort: %d", r.code)
	}
	if _, err := os.Stat(filepath.Join(dir, "u_"+id)); !os.IsNotExist(err) {
		t.Fatal("upload file not removed")
	}
	_ = io.Discard
}
