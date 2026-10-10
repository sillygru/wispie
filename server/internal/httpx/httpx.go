// Package httpx provides shared HTTP plumbing: errors, strict JSON,
// client IP resolution and privacy-safe logging.
package httpx

import (
	"encoding/json"
	"errors"
	"io"
	"log"
	"net"
	"net/http"
	"net/netip"
	"strconv"
	"strings"
	"time"
)

const MaxJSONBytes = 16 << 10

type Error struct {
	Status     int
	Code       string
	Message    string
	RetryAfter int
	Extra      map[string]any
}

func (e *Error) Error() string { return e.Code + ": " + e.Message }

func Err(status int, code, msg string) *Error {
	return &Error{Status: status, Code: code, Message: msg}
}

func RateLimited(wait time.Duration) *Error {
	s := int(wait.Seconds() + 0.999)
	if s < 1 {
		s = 1
	}
	return &Error{Status: 429, Code: "rate_limited", Message: "too many requests", RetryAfter: s}
}

func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func WriteError(w http.ResponseWriter, err error) {
	var he *Error
	if !errors.As(err, &he) {
		he = Err(500, "internal", "internal error")
	}
	body := map[string]any{"error": he.Code, "message": he.Message}
	for k, v := range he.Extra {
		body[k] = v
	}
	if he.RetryAfter > 0 {
		body["retry_after"] = he.RetryAfter
		w.Header().Set("Retry-After", strconv.Itoa(he.RetryAfter))
	}
	WriteJSON(w, he.Status, body)
}

// DecodeJSON reads a size-limited body, rejecting unknown fields and trailing data.
func DecodeJSON(w http.ResponseWriter, r *http.Request, dst any) error {
	r.Body = http.MaxBytesReader(w, r.Body, MaxJSONBytes)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			return Err(413, "too_large", "request body too large")
		}
		return Err(400, "bad_request", "invalid JSON body")
	}
	if _, err := dec.Token(); err != io.EOF {
		return Err(400, "bad_request", "unexpected trailing data")
	}
	return nil
}

func inPrefixes(a netip.Addr, ps []netip.Prefix) bool {
	for _, p := range ps {
		if p.Contains(a) {
			return true
		}
	}
	return false
}

// ClientIP uses the socket peer, or X-Forwarded-For only if the peer is a trusted proxy.
func ClientIP(r *http.Request, trusted []netip.Prefix) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	peer, perr := netip.ParseAddr(host)
	if perr != nil {
		return host
	}
	peer = peer.Unmap()
	if !inPrefixes(peer, trusted) {
		return peer.String()
	}
	xff := r.Header.Get("X-Forwarded-For")
	if xff == "" {
		return peer.String()
	}
	parts := strings.Split(xff, ",")
	for i := len(parts) - 1; i >= 0; i-- {
		a, err := netip.ParseAddr(strings.TrimSpace(parts[i]))
		if err != nil {
			return peer.String()
		}
		a = a.Unmap()
		if !inPrefixes(a, trusted) {
			return a.String()
		}
	}
	return peer.String()
}

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (s *statusWriter) WriteHeader(c int) {
	s.status = c
	s.ResponseWriter.WriteHeader(c)
}

func (s *statusWriter) Unwrap() http.ResponseWriter { return s.ResponseWriter }

// Logging records only method, route pattern, status and duration.
// Never the path (may hold ids), query, IP or headers.
func Logging(l *log.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sw := &statusWriter{ResponseWriter: w, status: 200}
		start := time.Now()
		next.ServeHTTP(sw, r)
		pat := r.Pattern
		if pat == "" {
			pat = "unmatched"
		}
		l.Printf("%s %d %s", pat, sw.status, time.Since(start).Round(time.Millisecond))
	})
}

func Handler(f func(w http.ResponseWriter, r *http.Request) error) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if err := f(w, r); err != nil {
			WriteError(w, err)
		}
	}
}
