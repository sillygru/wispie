// Package pow implements stateless hashcash challenges for registration.
package pow

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"math/bits"
	"strings"
	"time"
)

var ErrInvalid = errors.New("invalid proof of work")

// Challenge is "<random16>.<expiryUnix>.<mac>" bound to account id and bits,
// so no server-side state is needed until the proof is verified.
func NewChallenge(secret []byte, accountID string, powBits int, ttl time.Duration, now time.Time) (string, time.Time) {
	r := make([]byte, 16)
	_, _ = rand.Read(r)
	exp := now.Add(ttl)
	body := base64.RawURLEncoding.EncodeToString(r) + "." + base64.RawURLEncoding.EncodeToString(expBytes(exp))
	return body + "." + mac(secret, body, accountID, powBits), exp
}

func expBytes(t time.Time) []byte {
	b := make([]byte, 8)
	binary.BigEndian.PutUint64(b, uint64(t.Unix()))
	return b
}

func mac(secret []byte, body, accountID string, powBits int) string {
	h := hmac.New(sha256.New, secret)
	h.Write([]byte("wispie/pow/v1|" + body + "|" + accountID + "|"))
	h.Write([]byte{byte(powBits)})
	return base64.RawURLEncoding.EncodeToString(h.Sum(nil))
}

// Verify checks challenge integrity, expiry and that
// SHA-256(challenge || nonce) has at least powBits leading zero bits.
func Verify(secret []byte, accountID, challenge, nonce string, powBits int, now time.Time) error {
	parts := strings.Split(challenge, ".")
	if len(parts) != 3 {
		return ErrInvalid
	}
	body := parts[0] + "." + parts[1]
	if !hmac.Equal([]byte(mac(secret, body, accountID, powBits)), []byte(parts[2])) {
		return ErrInvalid
	}
	eb, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil || len(eb) != 8 {
		return ErrInvalid
	}
	if now.Unix() > int64(binary.BigEndian.Uint64(eb)) {
		return ErrInvalid
	}
	if len(nonce) == 0 || len(nonce) > 64 {
		return ErrInvalid
	}
	if LeadingZeroBits(sha256.Sum256([]byte(challenge+nonce))) < powBits {
		return ErrInvalid
	}
	return nil
}

func LeadingZeroBits(sum [32]byte) int {
	n := 0
	for _, b := range sum {
		if b == 0 {
			n += 8
			continue
		}
		return n + bits.LeadingZeros8(b)
	}
	return n
}

// Solve is used by tests and tooling.
func Solve(challenge string, powBits int) string {
	for i := uint64(0); ; i++ {
		nonce := base64.RawURLEncoding.EncodeToString(binary.BigEndian.AppendUint64(nil, i))
		if LeadingZeroBits(sha256.Sum256([]byte(challenge+nonce))) >= powBits {
			return nonce
		}
	}
}

// LeadingZeroBitsOf is a test helper.
func LeadingZeroBitsOf(challenge, nonce string) int {
	return LeadingZeroBits(sha256.Sum256([]byte(challenge + nonce)))
}
