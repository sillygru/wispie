package server

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/sillygru/wispie/server/internal/config"
	"github.com/sillygru/wispie/server/internal/pow"
	"github.com/sillygru/wispie/server/internal/store"
)

type clock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *clock) Now() time.Time { c.mu.Lock(); defer c.mu.Unlock(); return c.t }
func (c *clock) Add(d time.Duration) {
	c.mu.Lock()
	c.t = c.t.Add(d)
	c.mu.Unlock()
}

type env struct {
	t   *testing.T
	st  *store.Store
	h   http.Handler
	srv *Server
	clk *clock
	log *bytes.Buffer
	cfg config.Config
}

func newEnv(t *testing.T, mod func(*config.Config)) *env {
	t.Helper()
	cfg := config.Default()
	cfg.PowBits = 8
	cfg.GlobalPerMin, cfg.GlobalBurst = 100000, 100000
	cfg.RegisterPerHour, cfg.RegisterPerDay, cfg.RegisterGlobalHr = 1000, 1000, 1000
	cfg.LoginPerMin = 1000
	if mod != nil {
		mod(&cfg)
	}
	st, err := store.Open(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { st.Close() })
	clk := &clock{t: time.Unix(1_700_000_000, 0)}
	buf := &bytes.Buffer{}
	s := New(cfg, st, clk.Now, log.New(buf, "", 0))
	return &env{t: t, st: st, h: s.Handler, srv: s, clk: clk, log: buf, cfg: cfg}
}

func b64(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }

func fill(n int, v byte) string { return b64(bytes.Repeat([]byte{v}, n)) }

type resp struct {
	code int
	body map[string]any
	hdr  http.Header
}

func (e *env) do(method, path, token string, body any) resp {
	e.t.Helper()
	var rd *bytes.Reader
	if s, ok := body.(string); ok {
		rd = bytes.NewReader([]byte(s))
	} else {
		bs, _ := json.Marshal(body)
		rd = bytes.NewReader(bs)
	}
	req := httptest.NewRequest(method, path, rd)
	req.RemoteAddr = "203.0.113.7:4444"
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	e.h.ServeHTTP(rec, req)
	out := resp{code: rec.Code, hdr: rec.Header()}
	_ = json.Unmarshal(rec.Body.Bytes(), &out.body)
	return out
}

func str(m map[string]any, k string) string { s, _ := m[k].(string); return s }

type acct struct {
	user, id, access, refresh string
	authKey, recAuth          string
}

func (e *env) register(user string) acct {
	e.t.Helper()
	r := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": user})
	if r.code != 200 {
		e.t.Fatalf("begin: %d %v", r.code, r.body)
	}
	id := str(r.body, "account_id")
	ch := str(r.body["pow"].(map[string]any), "challenge")
	a := acct{user: user, id: id, authKey: fill(32, 1), recAuth: fill(32, 2)}
	r = e.do("POST", "/v1/auth/register/finish", "", e.finishBody(a, ch, pow.Solve(ch, e.cfg.PowBits)))
	if r.code != 200 {
		e.t.Fatalf("finish: %d %v", r.code, r.body)
	}
	a.access, a.refresh = str(r.body, "access_token"), str(r.body, "refresh_token")
	return a
}

func (e *env) finishBody(a acct, ch, nonce string) map[string]any {
	return map[string]any{
		"account_id": a.id, "username": a.user, "pow_nonce": nonce, "pow_challenge": ch,
		"salt": fill(16, 3), "kdf": map[string]any{"alg": "argon2id", "m_kib": 65536, "t": 3, "p": 1},
		"auth_key": a.authKey, "recovery_auth": a.recAuth,
		"wrapped_by_pw": fill(72, 4), "wrapped_by_rk": fill(72, 5),
	}
}

func TestRegisterLoginRefreshReuseLogout(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("alice")
	if r := e.do("GET", "/v1/account", a.access, nil); r.code != 200 || str(r.body, "username") != "alice" {
		t.Fatalf("account: %d %v", r.code, r.body)
	}
	if r := e.do("POST", "/v1/auth/login", "", map[string]any{"username": "alice", "auth_key": fill(32, 9)}); r.code != 401 {
		t.Fatalf("bad login: %d", r.code)
	}
	r := e.do("POST", "/v1/auth/login", "", map[string]any{"username": "alice", "auth_key": a.authKey})
	if r.code != 200 || str(r.body, "wrapped_by_pw") != fill(72, 4) {
		t.Fatalf("login: %d %v", r.code, r.body)
	}
	acc, ref := str(r.body, "access_token"), str(r.body, "refresh_token")

	r2 := e.do("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": ref})
	if r2.code != 200 {
		t.Fatalf("refresh: %d", r2.code)
	}
	acc2, ref2 := str(r2.body, "access_token"), str(r2.body, "refresh_token")
	if r := e.do("GET", "/v1/account", acc, nil); r.code != 401 {
		t.Fatalf("old access should die after rotation: %d", r.code)
	}
	if r := e.do("GET", "/v1/account", acc2, nil); r.code != 200 {
		t.Fatalf("new access: %d", r.code)
	}
	// Replay of the rotated token revokes the whole family.
	if r := e.do("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": ref}); r.code != 401 {
		t.Fatalf("reuse: %d", r.code)
	}
	if r := e.do("GET", "/v1/account", acc2, nil); r.code != 401 {
		t.Fatalf("family should be revoked: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": ref2}); r.code != 401 {
		t.Fatalf("family refresh should fail: %d", r.code)
	}
	// Original registration session is a different family and survives.
	if r := e.do("GET", "/v1/account", a.access, nil); r.code != 200 {
		t.Fatalf("other family: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/logout", a.access, nil); r.code != 204 {
		t.Fatalf("logout: %d", r.code)
	}
	if r := e.do("GET", "/v1/account", a.access, nil); r.code != 401 {
		t.Fatalf("after logout: %d", r.code)
	}
}

func TestAccessExpiry(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("bob")
	e.clk.Add(16 * time.Minute)
	if r := e.do("GET", "/v1/account", a.access, nil); r.code != 401 {
		t.Fatalf("expired: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/refresh", "", map[string]any{"refresh_token": a.refresh}); r.code != 200 {
		t.Fatalf("refresh: %d", r.code)
	}
}

func TestUsernameTakenAndValidation(t *testing.T) {
	e := newEnv(t, nil)
	e.register("carol")
	if r := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "carol"}); r.code != 409 || str(r.body, "error") != "username_taken" {
		t.Fatalf("taken: %d %v", r.code, r.body)
	}
	if r := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "Bad Name"}); r.code != 400 {
		t.Fatalf("invalid: %d", r.code)
	}
	// Reservation blocks, then expires.
	e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "dave"})
	if r := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "dave"}); r.code != 409 {
		t.Fatalf("reserved: %d", r.code)
	}
	e.clk.Add(11 * time.Minute)
	if r := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "dave"}); r.code != 200 {
		t.Fatalf("after expiry: %d", r.code)
	}
}

func TestRegisterBadPow(t *testing.T) {
	e := newEnv(t, nil)
	r := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "erin"})
	id, ch := str(r.body, "account_id"), str(r.body["pow"].(map[string]any), "challenge")
	a := acct{user: "erin", id: id, authKey: fill(32, 1), recAuth: fill(32, 2)}
	// Find a nonce that fails.
	bad := "x"
	for i := 0; pow.Verify(e.st.Secret, id, ch, bad, 8, e.clk.Now()) == nil; i++ {
		bad = strings.Repeat("y", i+1)
	}
	if r := e.do("POST", "/v1/auth/register/finish", "", e.finishBody(a, ch, bad)); r.code != 400 || str(r.body, "error") != "pow_invalid" {
		t.Fatalf("bad pow: %d %v", r.code, r.body)
	}
	// Challenge bound to a different account id.
	r2 := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "frank"})
	b := acct{user: "frank", id: str(r2.body, "account_id"), authKey: a.authKey, recAuth: a.recAuth}
	if r := e.do("POST", "/v1/auth/register/finish", "", e.finishBody(b, ch, pow.Solve(ch, 8))); r.code != 400 {
		t.Fatalf("cross-account challenge: %d", r.code)
	}
	// Replay after success fails.
	good := e.finishBody(a, ch, pow.Solve(ch, 8))
	if r := e.do("POST", "/v1/auth/register/finish", "", good); r.code != 200 {
		t.Fatalf("good: %d %v", r.code, r.body)
	}
	if r := e.do("POST", "/v1/auth/register/finish", "", good); r.code == 200 {
		t.Fatal("replayed registration accepted")
	}
}

func TestRegistrationClosed(t *testing.T) {
	e := newEnv(t, func(c *config.Config) { c.RegistrationOpen = false })
	if r := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "gina"}); r.code != 403 {
		t.Fatalf("closed: %d", r.code)
	}
	if r := e.do("GET", "/v1/info", "", nil); r.body["registration_open"] != false {
		t.Fatalf("info: %v", r.body)
	}
}

func TestPreloginFakeSaltDeterministic(t *testing.T) {
	e := newEnv(t, nil)
	e.register("hank")
	r1 := e.do("POST", "/v1/auth/prelogin", "", map[string]any{"username": "nobody"})
	r2 := e.do("POST", "/v1/auth/prelogin", "", map[string]any{"username": "nobody"})
	if r1.code != 200 || str(r1.body, "salt") == "" || str(r1.body, "salt") != str(r2.body, "salt") {
		t.Fatalf("fake salt not deterministic: %v %v", r1.body, r2.body)
	}
	r3 := e.do("POST", "/v1/auth/prelogin", "", map[string]any{"username": "nobody2"})
	if str(r3.body, "salt") == str(r1.body, "salt") {
		t.Fatal("fake salts equal across users")
	}
	real := e.do("POST", "/v1/auth/prelogin", "", map[string]any{"username": "hank"})
	if str(real.body, "salt") != fill(16, 3) {
		t.Fatalf("real salt: %v", real.body)
	}
	// Same response shape for real and fake.
	if len(real.body) != len(r1.body) || real.body["kdf"] == nil || r1.body["kdf"] == nil {
		t.Fatal("shape differs")
	}
}

func TestLoginLockout(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("ivy")
	bad := map[string]any{"username": "ivy", "auth_key": fill(32, 9)}
	for i := 0; i < 5; i++ {
		if r := e.do("POST", "/v1/auth/login", "", bad); r.code != 401 {
			t.Fatalf("fail %d: %d", i, r.code)
		}
	}
	r := e.do("POST", "/v1/auth/login", "", map[string]any{"username": "ivy", "auth_key": a.authKey})
	if r.code != 429 || r.hdr.Get("Retry-After") == "" {
		t.Fatalf("locked: %d %v", r.code, r.body)
	}
	e.clk.Add(31 * time.Second)
	if r := e.do("POST", "/v1/auth/login", "", map[string]any{"username": "ivy", "auth_key": a.authKey}); r.code != 200 {
		t.Fatalf("after lockout: %d", r.code)
	}
	// Unknown usernames lock out identically (no enumeration).
	for i := 0; i < 5; i++ {
		e.do("POST", "/v1/auth/login", "", map[string]any{"username": "ghost", "auth_key": fill(32, 9)})
	}
	if r := e.do("POST", "/v1/auth/login", "", map[string]any{"username": "ghost", "auth_key": fill(32, 9)}); r.code != 429 {
		t.Fatalf("ghost lockout: %d", r.code)
	}
}

func TestRateLimits(t *testing.T) {
	e := newEnv(t, func(c *config.Config) {
		c.RegisterPerHour = 2
		c.GlobalPerMin, c.GlobalBurst = 60, 5
	})
	for i := 0; i < 2; i++ {
		e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "user" + string(rune('a'+i))})
	}
	// Global limiter (burst 5) may trip first; advance clock to isolate.
	e.clk.Add(time.Minute)
	r := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "userz"})
	if r.code != 429 || str(r.body, "error") != "rate_limited" || r.body["retry_after"] == nil {
		t.Fatalf("register limit: %d %v", r.code, r.body)
	}
	e.clk.Add(time.Hour)
	for i := 0; i < 5; i++ {
		e.do("GET", "/v1/info", "", nil)
	}
	if r := e.do("GET", "/v1/info", "", nil); r.code != 429 {
		t.Fatalf("global limit: %d", r.code)
	}
}

func TestBodyLimitsAndStrictJSON(t *testing.T) {
	e := newEnv(t, nil)
	big := `{"username":"` + strings.Repeat("a", 20000) + `"}`
	if r := e.do("POST", "/v1/auth/prelogin", "", big); r.code != 413 {
		t.Fatalf("big: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/prelogin", "", `{"username":"abc","extra":1}`); r.code != 400 {
		t.Fatalf("unknown field: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/prelogin", "", `{"username":"abc"} {"x":1}`); r.code != 400 {
		t.Fatalf("trailing: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/prelogin", "", `not json`); r.code != 400 || str(r.body, "error") != "bad_request" {
		t.Fatalf("garbage: %d %v", r.code, r.body)
	}
}

func TestPasswordChange(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("jon")
	r := e.do("POST", "/v1/auth/login", "", map[string]any{"username": "jon", "auth_key": a.authKey})
	other := str(r.body, "access_token")
	body := map[string]any{
		"current_auth_key": fill(32, 7), "salt": fill(16, 6), "kdf": map[string]any{"alg": "argon2id", "m_kib": 65536, "t": 3, "p": 1},
		"auth_key": fill(32, 8), "wrapped_by_pw": fill(72, 10),
	}
	if r := e.do("POST", "/v1/account/password", a.access, body); r.code != 401 {
		t.Fatalf("wrong current: %d", r.code)
	}
	body["current_auth_key"] = a.authKey
	if r := e.do("POST", "/v1/account/password", a.access, body); r.code != 200 {
		t.Fatalf("change: %d %v", r.code, r.body)
	}
	if r := e.do("GET", "/v1/account", other, nil); r.code != 401 {
		t.Fatalf("other session should be revoked: %d", r.code)
	}
	if r := e.do("GET", "/v1/account", a.access, nil); r.code != 200 {
		t.Fatalf("current session kept: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/login", "", map[string]any{"username": "jon", "auth_key": a.authKey}); r.code != 401 {
		t.Fatalf("old password: %d", r.code)
	}
	r = e.do("POST", "/v1/auth/login", "", map[string]any{"username": "jon", "auth_key": fill(32, 8)})
	if r.code != 200 || str(r.body, "wrapped_by_pw") != fill(72, 10) {
		t.Fatalf("new password: %d %v", r.code, r.body)
	}
	if p := e.do("POST", "/v1/auth/prelogin", "", map[string]any{"username": "jon"}); str(p.body, "salt") != fill(16, 6) {
		t.Fatal("salt not updated")
	}
}

func TestRecovery(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("kim")
	if r := e.do("POST", "/v1/auth/recover/begin", "", map[string]any{"username": "kim", "recovery_auth": fill(32, 9)}); r.code != 401 {
		t.Fatalf("bad recovery: %d", r.code)
	}
	r := e.do("POST", "/v1/auth/recover/begin", "", map[string]any{"username": "kim", "recovery_auth": a.recAuth})
	if r.code != 200 || str(r.body, "wrapped_by_rk") != fill(72, 5) {
		t.Fatalf("begin: %d %v", r.code, r.body)
	}
	rt := str(r.body, "recover_token")
	body := map[string]any{"salt": fill(16, 11), "kdf": map[string]any{"alg": "argon2id", "m_kib": 65536, "t": 3, "p": 1}, "auth_key": fill(32, 12), "wrapped_by_pw": fill(72, 13)}
	if r := e.do("POST", "/v1/auth/recover/finish", "", body); r.code != 401 {
		t.Fatalf("no token: %d", r.code)
	}
	fin := e.do("POST", "/v1/auth/recover/finish", rt, body)
	if fin.code != 200 {
		t.Fatalf("finish: %d %v", fin.code, fin.body)
	}
	if r := e.do("POST", "/v1/auth/recover/finish", rt, body); r.code != 401 {
		t.Fatalf("token reuse: %d", r.code)
	}
	if r := e.do("GET", "/v1/account", a.access, nil); r.code != 401 {
		t.Fatalf("old sessions must be revoked: %d", r.code)
	}
	if r := e.do("GET", "/v1/account", str(fin.body, "access_token"), nil); r.code != 200 {
		t.Fatalf("new session: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/login", "", map[string]any{"username": "kim", "auth_key": fill(32, 12)}); r.code != 200 {
		t.Fatalf("login new pw: %d", r.code)
	}
	// Recovery key remains valid.
	if r := e.do("POST", "/v1/auth/recover/begin", "", map[string]any{"username": "kim", "recovery_auth": a.recAuth}); r.code != 200 {
		t.Fatalf("recovery key still valid: %d", r.code)
	}
	// Expired recover token.
	r = e.do("POST", "/v1/auth/recover/begin", "", map[string]any{"username": "kim", "recovery_auth": a.recAuth})
	e.clk.Add(11 * time.Minute)
	if r := e.do("POST", "/v1/auth/recover/finish", str(r.body, "recover_token"), body); r.code != 401 {
		t.Fatalf("expired token: %d", r.code)
	}
}

func TestRecoveryRateLimit(t *testing.T) {
	e := newEnv(t, nil)
	e.register("lee")
	for i := 0; i < 5; i++ {
		e.do("POST", "/v1/auth/recover/begin", "", map[string]any{"username": "lee", "recovery_auth": fill(32, 9)})
	}
	if r := e.do("POST", "/v1/auth/recover/begin", "", map[string]any{"username": "lee", "recovery_auth": fill(32, 9)}); r.code != 429 {
		t.Fatalf("recover limit: %d", r.code)
	}
}

func TestNewRecoveryKey(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("max")
	body := map[string]any{"current_auth_key": a.authKey, "recovery_auth": fill(32, 20), "wrapped_by_rk": fill(72, 21)}
	if r := e.do("POST", "/v1/account/recovery-key", a.access, body); r.code != 200 {
		t.Fatalf("new rk: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/recover/begin", "", map[string]any{"username": "max", "recovery_auth": a.recAuth}); r.code != 401 {
		t.Fatalf("old rk: %d", r.code)
	}
	r := e.do("POST", "/v1/auth/recover/begin", "", map[string]any{"username": "max", "recovery_auth": fill(32, 20)})
	if r.code != 200 || str(r.body, "wrapped_by_rk") != fill(72, 21) {
		t.Fatalf("new rk begin: %d %v", r.code, r.body)
	}
}

func TestDeleteAccount(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("nia")
	dir := e.st.BlobDir(a.id)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	_ = os.WriteFile(dir+"/x", []byte("blob"), 0o600)
	if r := e.do("DELETE", "/v1/account", a.access, map[string]any{"auth_key": fill(32, 9)}); r.code != 401 {
		t.Fatalf("wrong pw: %d", r.code)
	}
	if r := e.do("DELETE", "/v1/account", a.access, map[string]any{"auth_key": a.authKey}); r.code != 204 {
		t.Fatalf("delete: %d", r.code)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatal("blob dir not removed")
	}
	if r := e.do("GET", "/v1/account", a.access, nil); r.code != 401 {
		t.Fatalf("session after delete: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/login", "", map[string]any{"username": "nia", "auth_key": a.authKey}); r.code != 401 {
		t.Fatalf("login after delete: %d", r.code)
	}
	if r := e.do("POST", "/v1/auth/register/begin", "", map[string]any{"username": "nia"}); r.code != 200 {
		t.Fatalf("name reusable: %d", r.code)
	}
	s, _ := e.st.Stats()
	if s.Accounts != 0 {
		t.Fatalf("stats: %+v", s)
	}
}

func TestLogsContainNoIPOrUsername(t *testing.T) {
	e := newEnv(t, nil)
	a := e.register("oscar-secret")
	e.do("POST", "/v1/auth/login", "", map[string]any{"username": "oscar-secret", "auth_key": a.authKey})
	e.do("GET", "/v1/account", a.access, nil)
	out := e.log.String()
	if out == "" {
		t.Fatal("expected logs")
	}
	for _, bad := range []string{"203.0.113", "oscar", a.id, a.access} {
		if strings.Contains(out, bad) {
			t.Fatalf("log leaks %q:\n%s", bad, out)
		}
	}
	if !strings.Contains(out, "POST /v1/auth/login 200") {
		t.Fatalf("missing route pattern log:\n%s", out)
	}
}

func TestUnauthorized(t *testing.T) {
	e := newEnv(t, nil)
	for _, tok := range []string{"", "garbage", fill(32, 1)} {
		if r := e.do("GET", "/v1/account", tok, nil); r.code != 401 {
			t.Fatalf("token %q: %d", tok, r.code)
		}
	}
}
