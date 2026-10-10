package httpx

import (
	"net/http/httptest"
	"net/netip"
	"testing"
)

func TestClientIP(t *testing.T) {
	trusted := []netip.Prefix{netip.MustParsePrefix("10.0.0.0/8")}
	mk := func(remote, xff string) string {
		r := httptest.NewRequest("GET", "/", nil)
		r.RemoteAddr = remote
		if xff != "" {
			r.Header.Set("X-Forwarded-For", xff)
		}
		return ClientIP(r, trusted)
	}
	if got := mk("198.51.100.1:1", "9.9.9.9"); got != "198.51.100.1" {
		t.Fatalf("untrusted peer must ignore XFF: %s", got)
	}
	if got := mk("10.1.1.1:1", "9.9.9.9"); got != "9.9.9.9" {
		t.Fatalf("trusted: %s", got)
	}
	if got := mk("10.1.1.1:1", "6.6.6.6, 9.9.9.9, 10.2.2.2"); got != "9.9.9.9" {
		t.Fatalf("spoofed prefix: %s", got)
	}
	if got := mk("10.1.1.1:1", ""); got != "10.1.1.1" {
		t.Fatalf("no xff: %s", got)
	}
}
