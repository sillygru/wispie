package pow

import (
	"testing"
	"time"
)

func TestPow(t *testing.T) {
	secret := []byte("0123456789abcdef0123456789abcdef")
	now := time.Unix(1_700_000_000, 0)
	ch, _ := NewChallenge(secret, "acct", 10, time.Minute, now)
	n := Solve(ch, 10)
	if err := Verify(secret, "acct", ch, n, 10, now); err != nil {
		t.Fatal(err)
	}
	if Verify(secret, "other", ch, n, 10, now) == nil {
		t.Fatal("account binding")
	}
	if Verify(secret, "acct", ch, n, 11, now) == nil && LeadingZeroBitsOf(ch, n) < 11 {
		t.Fatal("bits binding")
	}
	if Verify(secret, "acct", ch, n, 10, now.Add(2*time.Minute)) == nil {
		t.Fatal("expiry")
	}
	if Verify([]byte("another-secret-another-secret-xx"), "acct", ch, n, 10, now) == nil {
		t.Fatal("secret")
	}
	if Verify(secret, "acct", ch+"x", n, 10, now) == nil {
		t.Fatal("tamper")
	}
}
