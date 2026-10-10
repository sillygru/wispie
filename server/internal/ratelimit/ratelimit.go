// Package ratelimit holds in-memory limiters. Nothing here is persisted:
// client IPs are only ever present as keyed hashes in RAM.
package ratelimit

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"sync"
	"time"
)

// Hasher maps IPs to opaque keys using a secret that rotates daily.
type Hasher struct {
	mu     sync.Mutex
	secret []byte
	day    int64
	now    func() time.Time
}

func NewHasher(now func() time.Time) *Hasher { return &Hasher{now: now} }

func (h *Hasher) Key(ip string) string {
	h.mu.Lock()
	defer h.mu.Unlock()
	d := h.now().Unix() / 86400
	if h.secret == nil || d != h.day {
		h.secret = make([]byte, 32)
		_, _ = rand.Read(h.secret)
		h.day = d
	}
	m := hmac.New(sha256.New, h.secret)
	m.Write([]byte(ip))
	return hex.EncodeToString(m.Sum(nil)[:12])
}

type bucket struct {
	tokens float64
	last   time.Time
}

// Limiter is a token bucket per key: refills `limit` tokens per `per`, up to burst.
type Limiter struct {
	mu      sync.Mutex
	rate    float64 // tokens per second
	burst   float64
	buckets map[string]*bucket
	now     func() time.Time
	ops     int
}

func New(limit int, per time.Duration, burst int, now func() time.Time) *Limiter {
	if burst < 1 {
		burst = limit
	}
	return &Limiter{
		rate:    float64(limit) / per.Seconds(),
		burst:   float64(burst),
		buckets: map[string]*bucket{},
		now:     now,
	}
}

// Allow consumes one token. When denied it returns the wait until one is available.
func (l *Limiter) Allow(key string) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	t := l.now()
	b := l.buckets[key]
	if b == nil {
		b = &bucket{tokens: l.burst, last: t}
		l.buckets[key] = b
	}
	b.tokens += t.Sub(b.last).Seconds() * l.rate
	if b.tokens > l.burst {
		b.tokens = l.burst
	}
	b.last = t
	l.ops++
	if l.ops%512 == 0 {
		l.gc(t)
	}
	if b.tokens >= 1 {
		b.tokens--
		return true, 0
	}
	if l.rate <= 0 {
		return false, time.Hour
	}
	return false, time.Duration((1 - b.tokens) / l.rate * float64(time.Second))
}

func (l *Limiter) gc(t time.Time) {
	for k, b := range l.buckets {
		if b.tokens+t.Sub(b.last).Seconds()*l.rate >= l.burst {
			delete(l.buckets, k)
		}
	}
}

// Lockout tracks failures per key and applies exponential delays
// (30s, 60s, ... capped at 15min) once the threshold is passed.
type Lockout struct {
	mu        sync.Mutex
	threshold int
	base, max time.Duration
	m         map[string]*lockState
	now       func() time.Time
}

type lockState struct {
	fails int
	until time.Time
	last  time.Time
}

func NewLockout(threshold int, base, max time.Duration, now func() time.Time) *Lockout {
	return &Lockout{threshold: threshold, base: base, max: max, m: map[string]*lockState{}, now: now}
}

func (l *Lockout) Check(key string) (bool, time.Duration) {
	l.mu.Lock()
	defer l.mu.Unlock()
	s := l.m[key]
	if s == nil {
		return true, 0
	}
	if d := s.until.Sub(l.now()); d > 0 {
		return false, d
	}
	return true, 0
}

func (l *Lockout) Fail(key string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	t := l.now()
	if len(l.m) > 10000 {
		for k, s := range l.m {
			if t.Sub(s.last) > time.Hour {
				delete(l.m, k)
			}
		}
	}
	s := l.m[key]
	if s == nil {
		s = &lockState{}
		l.m[key] = s
	}
	if t.Sub(s.last) > time.Hour {
		s.fails = 0
	}
	s.fails++
	s.last = t
	if s.fails >= l.threshold {
		d := l.base
		for i := l.threshold; i < s.fails && d < l.max; i++ {
			d *= 2
		}
		if d > l.max {
			d = l.max
		}
		s.until = t.Add(d)
	}
}

func (l *Lockout) Reset(key string) {
	l.mu.Lock()
	delete(l.m, key)
	l.mu.Unlock()
}
