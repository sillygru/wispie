// Package store owns the SQLite database, schema migrations, the server
// secret and the on-disk blob directory layout.
package store

import (
	"crypto/rand"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	DB      *sql.DB
	DataDir string
	Secret  []byte
}

var migrations = []string{
	`CREATE TABLE accounts (
		id TEXT PRIMARY KEY,
		username TEXT NOT NULL UNIQUE,
		salt BLOB NOT NULL,
		kdf_json TEXT NOT NULL,
		auth_hash BLOB NOT NULL,
		auth_hash_salt BLOB NOT NULL,
		recovery_hash BLOB NOT NULL,
		recovery_hash_salt BLOB NOT NULL,
		wrapped_by_pw BLOB NOT NULL,
		wrapped_by_rk BLOB NOT NULL,
		epoch INTEGER NOT NULL DEFAULT 0,
		head_seq INTEGER NOT NULL DEFAULT 0,
		usage_bytes INTEGER NOT NULL DEFAULT 0,
		created_day INTEGER NOT NULL,
		last_active_day INTEGER NOT NULL
	);
	CREATE TABLE sessions (
		id TEXT PRIMARY KEY,
		account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
		family_id TEXT NOT NULL,
		refresh_hash BLOB NOT NULL,
		prev_refresh_hash BLOB,
		access_hash BLOB NOT NULL,
		access_exp INTEGER NOT NULL,
		refresh_exp INTEGER NOT NULL,
		revoked INTEGER NOT NULL DEFAULT 0
	);
	CREATE UNIQUE INDEX sessions_refresh ON sessions(refresh_hash);
	CREATE INDEX sessions_prev_refresh ON sessions(prev_refresh_hash);
	CREATE UNIQUE INDEX sessions_access ON sessions(access_hash);
	CREATE INDEX sessions_account ON sessions(account_id);
	CREATE INDEX sessions_family ON sessions(family_id);
	CREATE TABLE deltas (
		account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
		seq INTEGER NOT NULL,
		epoch INTEGER NOT NULL,
		size INTEGER NOT NULL,
		file TEXT NOT NULL,
		created_day INTEGER NOT NULL,
		PRIMARY KEY (account_id, seq)
	);
	CREATE TABLE snapshots (
		account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
		id TEXT NOT NULL,
		epoch INTEGER NOT NULL,
		base_seq INTEGER NOT NULL,
		size INTEGER NOT NULL,
		file TEXT NOT NULL,
		created_day INTEGER NOT NULL,
		created_at INTEGER NOT NULL,
		PRIMARY KEY (account_id, id)
	);
	CREATE TABLE uploads (
		id TEXT PRIMARY KEY,
		account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
		kind TEXT NOT NULL,
		epoch INTEGER NOT NULL,
		base_seq INTEGER NOT NULL,
		size INTEGER NOT NULL,
		received INTEGER NOT NULL DEFAULT 0,
		file TEXT NOT NULL,
		expires_at INTEGER NOT NULL
	);
	CREATE INDEX uploads_account ON uploads(account_id);
	CREATE TABLE reservations (
		username TEXT PRIMARY KEY,
		account_id TEXT NOT NULL UNIQUE,
		expires_at INTEGER NOT NULL
	);
	CREATE TABLE recover_tokens (
		token_hash BLOB PRIMARY KEY,
		account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
		expires_at INTEGER NOT NULL
	);`,
}

func Open(dataDir string) (*Store, error) {
	if err := os.MkdirAll(filepath.Join(dataDir, "blobs"), 0o700); err != nil {
		return nil, err
	}
	secret, err := loadSecret(filepath.Join(dataDir, "secret"))
	if err != nil {
		return nil, err
	}
	dsn := "file:" + filepath.Join(dataDir, "wispie.db") +
		"?_pragma=journal_mode(WAL)&_pragma=busy_timeout(5000)&_pragma=foreign_keys(1)&_pragma=synchronous(NORMAL)&_txlock=immediate"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(8)
	s := &Store{DB: db, DataDir: dataDir, Secret: secret}
	if err := s.migrate(); err != nil {
		db.Close()
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() error { return s.DB.Close() }

func loadSecret(path string) ([]byte, error) {
	if b, err := os.ReadFile(path); err == nil {
		if len(b) != 32 {
			return nil, fmt.Errorf("secret file %s has wrong length", path)
		}
		return b, nil
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	if err := os.WriteFile(path, b, 0o600); err != nil {
		return nil, err
	}
	return b, nil
}

func (s *Store) migrate() error {
	var v int
	if err := s.DB.QueryRow(`PRAGMA user_version`).Scan(&v); err != nil {
		return err
	}
	for i := v; i < len(migrations); i++ {
		tx, err := s.DB.Begin()
		if err != nil {
			return err
		}
		if _, err := tx.Exec(migrations[i]); err != nil {
			tx.Rollback()
			return fmt.Errorf("migration %d: %w", i+1, err)
		}
		if _, err := tx.Exec(fmt.Sprintf(`PRAGMA user_version = %d`, i+1)); err != nil {
			tx.Rollback()
			return err
		}
		if err := tx.Commit(); err != nil {
			return err
		}
	}
	return nil
}

func Day(t time.Time) int64 { return t.Unix() / 86400 }

// BlobDir is where an account's blobs live. id must be a validated hex id.
func (s *Store) BlobDir(accountID string) string {
	return filepath.Join(s.DataDir, "blobs", accountID)
}

// CleanupExpired drops expired reservations, recover tokens and sessions.
func (s *Store) CleanupExpired(now time.Time) error {
	u := now.Unix()
	for _, q := range []string{
		`DELETE FROM reservations WHERE expires_at < ?1`,
		`DELETE FROM recover_tokens WHERE expires_at < ?1`,
		`DELETE FROM sessions WHERE refresh_exp < ?1 OR (revoked = 1 AND access_exp < ?1)`,
	} {
		if _, err := s.DB.Exec(q, u); err != nil {
			return err
		}
	}
	return nil
}

type Stats struct {
	Accounts     int64
	StorageBytes int64
}

func (s *Store) Stats() (Stats, error) {
	var st Stats
	err := s.DB.QueryRow(`SELECT COUNT(*), COALESCE(SUM(usage_bytes),0) FROM accounts`).Scan(&st.Accounts, &st.StorageBytes)
	return st, err
}

// DeleteAccount removes all rows (cascade) and the blob directory.
func (s *Store) DeleteAccount(id string) error {
	if _, err := s.DB.Exec(`DELETE FROM accounts WHERE id = ?`, id); err != nil {
		return err
	}
	return os.RemoveAll(s.BlobDir(id))
}
