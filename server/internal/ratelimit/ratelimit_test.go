package ratelimit

import (
	"testing"
	"time"
)

func TestLimiterRefill(t *testing.T) {
	now := time.Unix(0, 0)
	l := New(60, time.Minute, 2, func() time.Time { return now })
	if ok, _ := l.Allow("a"); !ok {
		t.Fatal()
	}
	l.Allow("a")
	ok, wait := l.Allow("a")
	if ok || wait <= 0 {
		t.Fatal("should deny")
	}
	if ok, _ := l.Allow("b"); !ok {
		t.Fatal("keys independent")
	}
	now = now.Add(time.Second)
	if ok, _ := l.Allow("a"); !ok {
		t.Fatal("refill")
	}
}

func TestLockoutExponential(t *testing.T) {
	now := time.Unix(0, 0)
	l := NewLockout(2, 30*time.Second, 2*time.Minute, func() time.Time { return now })
	l.Fail("u")
	if ok, _ := l.Check("u"); !ok {
		t.Fatal("below threshold")
	}
	l.Fail("u")
	if ok, d := l.Check("u"); ok || d != 30*time.Second {
		t.Fatalf("first lock %v", d)
	}
	now = now.Add(31 * time.Second)
	l.Fail("u")
	if _, d := l.Check("u"); d != 60*time.Second {
		t.Fatalf("second lock %v", d)
	}
	for i := 0; i < 10; i++ {
		now = now.Add(3 * time.Minute)
		l.Fail("u")
	}
	if _, d := l.Check("u"); d != 2*time.Minute {
		t.Fatalf("cap %v", d)
	}
}

func TestHasherRotates(t *testing.T) {
	now := time.Unix(0, 0)
	h := NewHasher(func() time.Time { return now })
	k1 := h.Key("1.2.3.4")
	if k1 != h.Key("1.2.3.4") || k1 == h.Key("1.2.3.5") {
		t.Fatal("stable per day")
	}
	now = now.Add(25 * time.Hour)
	if k1 == h.Key("1.2.3.4") {
		t.Fatal("should rotate")
	}
}
