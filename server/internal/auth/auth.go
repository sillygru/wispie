// Package auth implements accounts, sessions and recovery. The server only
// ever sees derived keys (auth_key, recovery_auth) and opaque wrapped blobs.
package auth

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"regexp"
	"strings"
	"time"

	"golang.org/x/crypto/argon2"

	"github.com/sillygru/wispie/server/internal/config"
	"github.com/sillygru/wispie/server/internal/httpx"
	"github.com/sillygru/wispie/server/internal/pow"
	"github.com/sillygru/wispie/server/internal/ratelimit"
	"github.com/sillygru/wispie/server/internal/store"
)

const (
	AccessTTL      = 15 * time.Minute
	RefreshTTL     = 60 * 24 * time.Hour
	ReservationTTL = 10 * time.Minute
	RecoverTTL     = 10 * time.Minute

	// Server-side hashing of the already-stretched client keys.
	hashMemKiB  = 19 * 1024
	hashTime    = 2
	hashThreads = 1
)

var usernameRe = regexp.MustCompile(`^[a-z0-9._-]{3,32}$`)

type KDF struct {
	Alg string `json:"alg"`
	M   uint32 `json:"m_kib"`
	T   uint32 `json:"t"`
	P   uint32 `json:"p"`
}

var DefaultKDF = KDF{Alg: "argon2id", M: 64 * 1024, T: 3, P: 1}

func (k KDF) valid() bool {
	return k.Alg == "argon2id" && k.M >= 32*1024 && k.M <= 256*1024 && k.T >= 2 && k.T <= 10 && k.P >= 1 && k.P <= 4
}

type Service struct {
	Store *store.Store
	Cfg   config.Config
	Now   func() time.Time

	ipHash      *ratelimit.Hasher
	globalIP    *ratelimit.Limiter
	regHour     *ratelimit.Limiter
	regDay      *ratelimit.Limiter
	regGlobal   *ratelimit.Limiter
	loginIP     *ratelimit.Limiter
	recoverIP   *ratelimit.Limiter
	recoverUser *ratelimit.Limiter
	lockout     *ratelimit.Lockout
	hashSem     chan struct{}
}

func New(st *store.Store, cfg config.Config, now func() time.Time) *Service {
	if now == nil {
		now = time.Now
	}
	return &Service{
		Store:       st,
		Cfg:         cfg,
		Now:         now,
		ipHash:      ratelimit.NewHasher(now),
		globalIP:    ratelimit.New(cfg.GlobalPerMin, time.Minute, cfg.GlobalBurst, now),
		regHour:     ratelimit.New(cfg.RegisterPerHour, time.Hour, cfg.RegisterPerHour, now),
		regDay:      ratelimit.New(cfg.RegisterPerDay, 24*time.Hour, cfg.RegisterPerDay, now),
		regGlobal:   ratelimit.New(cfg.RegisterGlobalHr, time.Hour, cfg.RegisterGlobalHr, now),
		loginIP:     ratelimit.New(cfg.LoginPerMin, time.Minute, cfg.LoginPerMin, now),
		recoverIP:   ratelimit.New(cfg.RecoverIPPerHour, time.Hour, cfg.RecoverIPPerHour, now),
		recoverUser: ratelimit.New(cfg.RecoverUserPerDay, 24*time.Hour, cfg.RecoverUserPerDay, now),
		lockout:     ratelimit.NewLockout(5, 30*time.Second, 15*time.Minute, now),
		hashSem:     make(chan struct{}, 4),
	}
}

// IPKey returns the in-memory limiter key for a request.
func (s *Service) IPKey(r *http.Request) string {
	return s.ipHash.Key(httpx.ClientIP(r, s.Cfg.TrustedProxies))
}

// GlobalLimit is middleware applying the per-IP global limit.
func (s *Service) GlobalLimit(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if ok, wait := s.globalIP.Allow(s.IPKey(r)); !ok {
			httpx.WriteError(w, httpx.RateLimited(wait))
			return
		}
		next.ServeHTTP(w, r)
	})
}

func allow(l *ratelimit.Limiter, key string) error {
	if ok, wait := l.Allow(key); !ok {
		return httpx.RateLimited(wait)
	}
	return nil
}

// Routes registers all auth and account endpoints.
func (s *Service) Routes(mux *http.ServeMux) {
	h := httpx.Handler
	mux.HandleFunc("GET /v1/info", h(s.info))
	mux.HandleFunc("POST /v1/auth/prelogin", h(s.prelogin))
	mux.HandleFunc("POST /v1/auth/register/begin", h(s.registerBegin))
	mux.HandleFunc("POST /v1/auth/register/finish", h(s.registerFinish))
	mux.HandleFunc("POST /v1/auth/login", h(s.login))
	mux.HandleFunc("POST /v1/auth/refresh", h(s.refresh))
	mux.HandleFunc("POST /v1/auth/logout", h(s.Require(s.logout)))
	mux.HandleFunc("POST /v1/auth/recover/begin", h(s.recoverBegin))
	mux.HandleFunc("POST /v1/auth/recover/finish", h(s.recoverFinish))
	mux.HandleFunc("POST /v1/account/password", h(s.Require(s.changePassword)))
	mux.HandleFunc("POST /v1/account/recovery-key", h(s.Require(s.newRecoveryKey)))
	mux.HandleFunc("GET /v1/account", h(s.Require(s.getAccount)))
	mux.HandleFunc("DELETE /v1/account", h(s.Require(s.deleteAccount)))
}

// ---- encoding helpers ----

func b64(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }

func decodeB64(s string, minLen, maxLen int) ([]byte, error) {
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil || len(b) < minLen || len(b) > maxLen {
		return nil, httpx.Err(400, "bad_request", "invalid encoded field")
	}
	return b, nil
}

func decodeFixed(s string, n int) ([]byte, error) { return decodeB64(s, n, n) }

func randBytes(n int) []byte {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return b
}

func sha(b []byte) []byte { h := sha256.Sum256(b); return h[:] }

func validUsername(u string) error {
	if !usernameRe.MatchString(u) {
		return httpx.Err(400, "bad_username", "username must be 3-32 characters of a-z 0-9 . _ -")
	}
	return nil
}

func (s *Service) hash(key, salt []byte) []byte {
	s.hashSem <- struct{}{}
	defer func() { <-s.hashSem }()
	return argon2.IDKey(key, salt, hashTime, hashMemKiB, hashThreads, 32)
}

func (s *Service) fakeSalt(username string) []byte {
	m := hmac.New(sha256.New, s.Store.Secret)
	m.Write([]byte("wispie/fake-salt/v1|" + username))
	return m.Sum(nil)[:16]
}

// ---- accounts ----

type Account struct {
	ID               string
	Username         string
	Salt             []byte
	KDF              KDF
	AuthHash         []byte
	AuthHashSalt     []byte
	RecoveryHash     []byte
	RecoveryHashSalt []byte
	WrappedByPw      []byte
	WrappedByRk      []byte
	UsageBytes       int64
	CreatedDay       int64
}

const accountCols = `id, username, salt, kdf_json, auth_hash, auth_hash_salt, recovery_hash, recovery_hash_salt, wrapped_by_pw, wrapped_by_rk, usage_bytes, created_day`

type rowScanner interface{ Scan(...any) error }

func scanAccount(r rowScanner) (*Account, error) {
	var a Account
	var kdf string
	if err := r.Scan(&a.ID, &a.Username, &a.Salt, &kdf, &a.AuthHash, &a.AuthHashSalt, &a.RecoveryHash, &a.RecoveryHashSalt, &a.WrappedByPw, &a.WrappedByRk, &a.UsageBytes, &a.CreatedDay); err != nil {
		return nil, err
	}
	if err := json.Unmarshal([]byte(kdf), &a.KDF); err != nil {
		return nil, err
	}
	return &a, nil
}

func (s *Service) accountByName(username string) (*Account, error) {
	a, err := scanAccount(s.Store.DB.QueryRow(`SELECT `+accountCols+` FROM accounts WHERE username = ?`, username))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return a, err
}

func (s *Service) accountByID(id string) (*Account, error) {
	a, err := scanAccount(s.Store.DB.QueryRow(`SELECT `+accountCols+` FROM accounts WHERE id = ?`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, httpx.Err(401, "unauthorized", "account not found")
	}
	return a, err
}

// ---- sessions ----

type Tokens struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
}

type execer interface {
	Exec(string, ...any) (sql.Result, error)
}

func (s *Service) issue(db execer, accountID, familyID string) (Tokens, error) {
	now := s.Now()
	if familyID == "" {
		familyID = hex.EncodeToString(randBytes(16))
	}
	access, refresh := randBytes(32), randBytes(32)
	_, err := db.Exec(`INSERT INTO sessions(id, account_id, family_id, refresh_hash, access_hash, access_exp, refresh_exp) VALUES(?,?,?,?,?,?,?)`,
		hex.EncodeToString(randBytes(16)), accountID, familyID, sha(refresh), sha(access),
		now.Add(AccessTTL).Unix(), now.Add(RefreshTTL).Unix())
	return Tokens{b64(access), b64(refresh), int(AccessTTL.Seconds())}, err
}

type Principal struct {
	AccountID string
	SessionID string
}

type ctxKey struct{}

// FromContext returns the authenticated principal set by Require.
func FromContext(ctx context.Context) Principal {
	p, _ := ctx.Value(ctxKey{}).(Principal)
	return p
}

func bearer(r *http.Request) ([]byte, error) {
	h := r.Header.Get("Authorization")
	t, ok := strings.CutPrefix(h, "Bearer ")
	if !ok {
		return nil, httpx.Err(401, "unauthorized", "missing bearer token")
	}
	b, err := base64.RawURLEncoding.DecodeString(strings.TrimSpace(t))
	if err != nil || len(b) != 32 {
		return nil, httpx.Err(401, "unauthorized", "invalid token")
	}
	return b, nil
}

func (s *Service) principal(r *http.Request) (Principal, error) {
	tok, err := bearer(r)
	if err != nil {
		return Principal{}, err
	}
	var p Principal
	var exp, rexp, revoked int64
	err = s.Store.DB.QueryRow(`SELECT id, account_id, access_exp, refresh_exp, revoked FROM sessions WHERE access_hash = ?`, sha(tok)).
		Scan(&p.SessionID, &p.AccountID, &exp, &rexp, &revoked)
	now := s.Now().Unix()
	if err != nil || revoked != 0 || exp < now || rexp < now {
		return Principal{}, httpx.Err(401, "unauthorized", "invalid or expired token")
	}
	_, _ = s.Store.DB.Exec(`UPDATE accounts SET last_active_day = ? WHERE id = ? AND last_active_day < ?`,
		store.Day(s.Now()), p.AccountID, store.Day(s.Now()))
	return p, nil
}

// Require wraps a handler so it only runs with a valid access token.
func (s *Service) Require(f func(http.ResponseWriter, *http.Request, Principal) error) func(http.ResponseWriter, *http.Request) error {
	return func(w http.ResponseWriter, r *http.Request) error {
		p, err := s.principal(r)
		if err != nil {
			return err
		}
		return f(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, p)), p)
	}
}

func (s *Service) revokeAll(accountID, exceptSession string) error {
	_, err := s.Store.DB.Exec(`UPDATE sessions SET revoked = 1 WHERE account_id = ? AND id != ?`, accountID, exceptSession)
	return err
}

// ---- handlers ----

func (s *Service) info(w http.ResponseWriter, r *http.Request) error {
	httpx.WriteJSON(w, 200, map[string]any{
		"name":              "wispie-sync",
		"api":               1,
		"registration_open": s.Cfg.RegistrationOpen,
		"pow_bits":          s.Cfg.PowBits,
		"limits": map[string]any{
			"max_delta_bytes": s.Cfg.MaxDeltaBytes,
			"chunk_bytes":     s.Cfg.ChunkBytes,
			"quota_bytes":     s.Cfg.QuotaBytes,
		},
	})
	return nil
}

type usernameReq struct {
	Username string `json:"username"`
}

func (s *Service) prelogin(w http.ResponseWriter, r *http.Request) error {
	var req usernameReq
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	if err := allow(s.loginIP, s.IPKey(r)); err != nil {
		return err
	}
	if err := validUsername(req.Username); err != nil {
		return err
	}
	a, err := s.accountByName(req.Username)
	if err != nil {
		return err
	}
	salt, kdf := s.fakeSalt(req.Username), DefaultKDF
	if a != nil {
		salt, kdf = a.Salt, a.KDF
	}
	httpx.WriteJSON(w, 200, map[string]any{"salt": b64(salt), "kdf": kdf})
	return nil
}

func (s *Service) registerBegin(w http.ResponseWriter, r *http.Request) error {
	var req usernameReq
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	if !s.Cfg.RegistrationOpen {
		return httpx.Err(403, "registration_closed", "registration is closed on this server")
	}
	ip := s.IPKey(r)
	for _, l := range []*ratelimit.Limiter{s.regHour, s.regDay} {
		if err := allow(l, ip); err != nil {
			return err
		}
	}
	if err := allow(s.regGlobal, "all"); err != nil {
		return err
	}
	if err := validUsername(req.Username); err != nil {
		return err
	}
	now := s.Now()
	id := hex.EncodeToString(randBytes(16))
	tx, err := s.Store.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var n int
	if err := tx.QueryRow(`SELECT COUNT(*) FROM accounts WHERE username = ?`, req.Username).Scan(&n); err != nil {
		return err
	}
	if n == 0 {
		if err := tx.QueryRow(`SELECT COUNT(*) FROM reservations WHERE username = ? AND expires_at >= ?`, req.Username, now.Unix()).Scan(&n); err != nil {
			return err
		}
	}
	if n > 0 {
		return httpx.Err(409, "username_taken", "username is not available")
	}
	if _, err := tx.Exec(`INSERT OR REPLACE INTO reservations(username, account_id, expires_at) VALUES(?,?,?)`,
		req.Username, id, now.Add(ReservationTTL).Unix()); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	ch, exp := pow.NewChallenge(s.Store.Secret, id, s.Cfg.PowBits, ReservationTTL, now)
	httpx.WriteJSON(w, 200, map[string]any{
		"account_id": id,
		"pow":        map[string]any{"challenge": ch, "bits": s.Cfg.PowBits, "expires": exp.Unix()},
	})
	return nil
}

type registerFinishReq struct {
	AccountID    string `json:"account_id"`
	Username     string `json:"username"`
	PowNonce     string `json:"pow_nonce"`
	Challenge    string `json:"pow_challenge"`
	Salt         string `json:"salt"`
	KDF          KDF    `json:"kdf"`
	AuthKey      string `json:"auth_key"`
	RecoveryAuth string `json:"recovery_auth"`
	WrappedByPw  string `json:"wrapped_by_pw"`
	WrappedByRk  string `json:"wrapped_by_rk"`
	DeviceLabel  string `json:"device_label,omitempty"`
}

func (s *Service) registerFinish(w http.ResponseWriter, r *http.Request) error {
	var req registerFinishReq
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	if !s.Cfg.RegistrationOpen {
		return httpx.Err(403, "registration_closed", "registration is closed on this server")
	}
	if err := allow(s.regGlobal, "all"); err != nil {
		return err
	}
	if err := validUsername(req.Username); err != nil {
		return err
	}
	if len(req.DeviceLabel) > 64 || len(req.AccountID) != 32 {
		return httpx.Err(400, "bad_request", "invalid field")
	}
	if !req.KDF.valid() {
		return httpx.Err(400, "bad_kdf", "unsupported KDF parameters")
	}
	salt, err := decodeFixed(req.Salt, 16)
	if err != nil {
		return err
	}
	authKey, err := decodeFixed(req.AuthKey, 32)
	if err != nil {
		return err
	}
	recAuth, err := decodeFixed(req.RecoveryAuth, 32)
	if err != nil {
		return err
	}
	wpw, err := decodeB64(req.WrappedByPw, 16, 512)
	if err != nil {
		return err
	}
	wrk, err := decodeB64(req.WrappedByRk, 16, 512)
	if err != nil {
		return err
	}
	now := s.Now()
	var resAcct string
	var resExp int64
	err = s.Store.DB.QueryRow(`SELECT account_id, expires_at FROM reservations WHERE username = ?`, req.Username).Scan(&resAcct, &resExp)
	if err != nil || resAcct != req.AccountID || resExp < now.Unix() {
		return httpx.Err(400, "reservation_invalid", "registration expired or not started")
	}
	if err := pow.Verify(s.Store.Secret, req.AccountID, req.Challenge, req.PowNonce, s.Cfg.PowBits, now); err != nil {
		return httpx.Err(400, "pow_invalid", "proof of work invalid or expired")
	}
	kdfJSON, _ := json.Marshal(req.KDF)
	aSalt, rSalt := randBytes(16), randBytes(16)
	aHash, rHash := s.hash(authKey, aSalt), s.hash(recAuth, rSalt)

	tx, err := s.Store.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	// Consuming the reservation makes the PoW single-use.
	res, err := tx.Exec(`DELETE FROM reservations WHERE username = ? AND account_id = ?`, req.Username, req.AccountID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n != 1 {
		return httpx.Err(400, "reservation_invalid", "registration expired or not started")
	}
	day := store.Day(now)
	if _, err := tx.Exec(`INSERT INTO accounts(id, username, salt, kdf_json, auth_hash, auth_hash_salt, recovery_hash, recovery_hash_salt, wrapped_by_pw, wrapped_by_rk, created_day, last_active_day)
		VALUES(?,?,?,?,?,?,?,?,?,?,?,?)`,
		req.AccountID, req.Username, salt, string(kdfJSON), aHash, aSalt, rHash, rSalt, wpw, wrk, day, day); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			return httpx.Err(409, "username_taken", "username is not available")
		}
		return err
	}
	tok, err := s.issue(tx, req.AccountID, "")
	if err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{
		"account_id": req.AccountID, "access_token": tok.AccessToken,
		"refresh_token": tok.RefreshToken, "expires_in": tok.ExpiresIn,
	})
	return nil
}

func eq(a, b []byte) bool { return subtle.ConstantTimeCompare(a, b) == 1 }

// verifyAuth checks an auth_key against an account's stored hash, or burns
// equivalent work for unknown accounts so timing does not reveal existence.
func (s *Service) verifyAuth(a *Account, key []byte) bool {
	if a == nil {
		s.hash(key, make([]byte, 16))
		return false
	}
	return eq(s.hash(key, a.AuthHashSalt), a.AuthHash)
}

func (s *Service) login(w http.ResponseWriter, r *http.Request) error {
	var req struct {
		Username string `json:"username"`
		AuthKey  string `json:"auth_key"`
	}
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	if err := allow(s.loginIP, s.IPKey(r)); err != nil {
		return err
	}
	if err := validUsername(req.Username); err != nil {
		return err
	}
	key, err := decodeFixed(req.AuthKey, 32)
	if err != nil {
		return err
	}
	if ok, wait := s.lockout.Check(req.Username); !ok {
		return httpx.RateLimited(wait)
	}
	a, err := s.accountByName(req.Username)
	if err != nil {
		return err
	}
	if !s.verifyAuth(a, key) {
		s.lockout.Fail(req.Username)
		return httpx.Err(401, "invalid_credentials", "invalid username or password")
	}
	s.lockout.Reset(req.Username)
	tok, err := s.issue(s.Store.DB, a.ID, "")
	if err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{
		"access_token": tok.AccessToken, "refresh_token": tok.RefreshToken, "expires_in": tok.ExpiresIn,
		"account_id": a.ID, "wrapped_by_pw": b64(a.WrappedByPw),
	})
	return nil
}

func (s *Service) refresh(w http.ResponseWriter, r *http.Request) error {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	if err := allow(s.loginIP, s.IPKey(r)); err != nil {
		return err
	}
	rt, err := decodeFixed(req.RefreshToken, 32)
	if err != nil {
		return httpx.Err(401, "unauthorized", "invalid refresh token")
	}
	h := sha(rt)
	now := s.Now().Unix()
	tx, err := s.Store.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var id, acct, fam string
	var rexp, revoked int64
	err = tx.QueryRow(`SELECT id, account_id, family_id, refresh_exp, revoked FROM sessions WHERE refresh_hash = ?`, h).
		Scan(&id, &acct, &fam, &rexp, &revoked)
	if errors.Is(err, sql.ErrNoRows) {
		// A previously rotated token being replayed means it leaked: kill the family.
		var pfam string
		if e := tx.QueryRow(`SELECT family_id FROM sessions WHERE prev_refresh_hash = ?`, h).Scan(&pfam); e == nil {
			if _, e := tx.Exec(`UPDATE sessions SET revoked = 1 WHERE family_id = ?`, pfam); e != nil {
				return e
			}
			if e := tx.Commit(); e != nil {
				return e
			}
		}
		return httpx.Err(401, "unauthorized", "invalid refresh token")
	}
	if err != nil {
		return err
	}
	if revoked != 0 || rexp < now {
		return httpx.Err(401, "unauthorized", "invalid refresh token")
	}
	access, refresh := randBytes(32), randBytes(32)
	t := s.Now()
	if _, err := tx.Exec(`UPDATE sessions SET prev_refresh_hash = refresh_hash, refresh_hash = ?, access_hash = ?, access_exp = ?, refresh_exp = ? WHERE id = ?`,
		sha(refresh), sha(access), t.Add(AccessTTL).Unix(), t.Add(RefreshTTL).Unix(), id); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{
		"access_token": b64(access), "refresh_token": b64(refresh),
		"expires_in": int(AccessTTL.Seconds()), "account_id": acct,
	})
	return nil
}

func (s *Service) logout(w http.ResponseWriter, r *http.Request, p Principal) error {
	if _, err := s.Store.DB.Exec(`UPDATE sessions SET revoked = 1 WHERE id = ?`, p.SessionID); err != nil {
		return err
	}
	w.WriteHeader(http.StatusNoContent)
	return nil
}

func (s *Service) recoverBegin(w http.ResponseWriter, r *http.Request) error {
	var req struct {
		Username     string `json:"username"`
		RecoveryAuth string `json:"recovery_auth"`
	}
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	if err := validUsername(req.Username); err != nil {
		return err
	}
	if err := allow(s.recoverIP, s.IPKey(r)); err != nil {
		return err
	}
	if err := allow(s.recoverUser, req.Username); err != nil {
		return err
	}
	key, err := decodeFixed(req.RecoveryAuth, 32)
	if err != nil {
		return err
	}
	a, err := s.accountByName(req.Username)
	if err != nil {
		return err
	}
	ok := false
	if a == nil {
		s.hash(key, make([]byte, 16))
	} else {
		ok = eq(s.hash(key, a.RecoveryHashSalt), a.RecoveryHash)
	}
	if !ok {
		return httpx.Err(401, "invalid_credentials", "invalid username or recovery key")
	}
	tok := randBytes(32)
	if _, err := s.Store.DB.Exec(`INSERT INTO recover_tokens(token_hash, account_id, expires_at) VALUES(?,?,?)`,
		sha(tok), a.ID, s.Now().Add(RecoverTTL).Unix()); err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{
		"account_id": a.ID, "wrapped_by_rk": b64(a.WrappedByRk), "recover_token": b64(tok),
	})
	return nil
}

type credsUpdate struct {
	Salt        string `json:"salt"`
	KDF         KDF    `json:"kdf"`
	AuthKey     string `json:"auth_key"`
	WrappedByPw string `json:"wrapped_by_pw"`
}

type parsedCreds struct {
	salt, authKey, wrapped, kdfJSON []byte
}

func (c credsUpdate) parse() (parsedCreds, error) {
	var p parsedCreds
	if !c.KDF.valid() {
		return p, httpx.Err(400, "bad_kdf", "unsupported KDF parameters")
	}
	var err error
	if p.salt, err = decodeFixed(c.Salt, 16); err != nil {
		return p, err
	}
	if p.authKey, err = decodeFixed(c.AuthKey, 32); err != nil {
		return p, err
	}
	if p.wrapped, err = decodeB64(c.WrappedByPw, 16, 512); err != nil {
		return p, err
	}
	p.kdfJSON, _ = json.Marshal(c.KDF)
	return p, nil
}

func (s *Service) setCreds(db execer, id string, p parsedCreds) error {
	aSalt := randBytes(16)
	_, err := db.Exec(`UPDATE accounts SET salt=?, kdf_json=?, auth_hash=?, auth_hash_salt=?, wrapped_by_pw=? WHERE id=?`,
		p.salt, string(p.kdfJSON), s.hash(p.authKey, aSalt), aSalt, p.wrapped, id)
	return err
}

func (s *Service) recoverFinish(w http.ResponseWriter, r *http.Request) error {
	tok, err := bearer(r)
	if err != nil {
		return err
	}
	var req credsUpdate
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	p, err := req.parse()
	if err != nil {
		return err
	}
	tx, err := s.Store.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	var acct string
	var exp int64
	if err := tx.QueryRow(`DELETE FROM recover_tokens WHERE token_hash = ? RETURNING account_id, expires_at`, sha(tok)).Scan(&acct, &exp); err != nil || exp < s.Now().Unix() {
		return httpx.Err(401, "unauthorized", "invalid or expired recovery token")
	}
	if err := s.setCreds(tx, acct, p); err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE sessions SET revoked = 1 WHERE account_id = ?`, acct); err != nil {
		return err
	}
	if _, err := tx.Exec(`DELETE FROM recover_tokens WHERE account_id = ?`, acct); err != nil {
		return err
	}
	tokens, err := s.issue(tx, acct, "")
	if err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	var uname string
	if s.Store.DB.QueryRow(`SELECT username FROM accounts WHERE id = ?`, acct).Scan(&uname) == nil {
		s.lockout.Reset(uname)
	}
	httpx.WriteJSON(w, 200, map[string]any{
		"account_id": acct, "access_token": tokens.AccessToken,
		"refresh_token": tokens.RefreshToken, "expires_in": tokens.ExpiresIn,
	})
	return nil
}

// verifyCurrent re-proves the password for sensitive operations, sharing
// the login lockout so it cannot be used to brute force.
func (s *Service) verifyCurrent(a *Account, authKey string) error {
	key, err := decodeFixed(authKey, 32)
	if err != nil {
		return err
	}
	if ok, wait := s.lockout.Check(a.Username); !ok {
		return httpx.RateLimited(wait)
	}
	if !s.verifyAuth(a, key) {
		s.lockout.Fail(a.Username)
		return httpx.Err(401, "invalid_credentials", "invalid password")
	}
	s.lockout.Reset(a.Username)
	return nil
}

func (s *Service) changePassword(w http.ResponseWriter, r *http.Request, p Principal) error {
	var req struct {
		CurrentAuthKey string `json:"current_auth_key"`
		credsUpdate
	}
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	creds, err := req.credsUpdate.parse()
	if err != nil {
		return err
	}
	a, err := s.accountByID(p.AccountID)
	if err != nil {
		return err
	}
	if err := s.verifyCurrent(a, req.CurrentAuthKey); err != nil {
		return err
	}
	if err := s.setCreds(s.Store.DB, a.ID, creds); err != nil {
		return err
	}
	if err := s.revokeAll(a.ID, p.SessionID); err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{})
	return nil
}

func (s *Service) newRecoveryKey(w http.ResponseWriter, r *http.Request, p Principal) error {
	var req struct {
		CurrentAuthKey string `json:"current_auth_key"`
		RecoveryAuth   string `json:"recovery_auth"`
		WrappedByRk    string `json:"wrapped_by_rk"`
	}
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	ra, err := decodeFixed(req.RecoveryAuth, 32)
	if err != nil {
		return err
	}
	wrk, err := decodeB64(req.WrappedByRk, 16, 512)
	if err != nil {
		return err
	}
	a, err := s.accountByID(p.AccountID)
	if err != nil {
		return err
	}
	if err := s.verifyCurrent(a, req.CurrentAuthKey); err != nil {
		return err
	}
	salt := randBytes(16)
	if _, err := s.Store.DB.Exec(`UPDATE accounts SET recovery_hash=?, recovery_hash_salt=?, wrapped_by_rk=? WHERE id=?`,
		s.hash(ra, salt), salt, wrk, a.ID); err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{})
	return nil
}

func (s *Service) getAccount(w http.ResponseWriter, r *http.Request, p Principal) error {
	a, err := s.accountByID(p.AccountID)
	if err != nil {
		return err
	}
	httpx.WriteJSON(w, 200, map[string]any{
		"username": a.Username, "usage_bytes": a.UsageBytes, "quota_bytes": s.Cfg.QuotaBytes,
		"created_day": time.Unix(a.CreatedDay*86400, 0).UTC().Format("2006-01-02"),
	})
	return nil
}

func (s *Service) deleteAccount(w http.ResponseWriter, r *http.Request, p Principal) error {
	var req struct {
		AuthKey string `json:"auth_key"`
	}
	if err := httpx.DecodeJSON(w, r, &req); err != nil {
		return err
	}
	a, err := s.accountByID(p.AccountID)
	if err != nil {
		return err
	}
	if err := s.verifyCurrent(a, req.AuthKey); err != nil {
		return err
	}
	if err := s.Store.DeleteAccount(a.ID); err != nil {
		return err
	}
	w.WriteHeader(http.StatusNoContent)
	return nil
}
