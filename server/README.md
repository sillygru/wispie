# wispie-server

Self-hostable, end-to-end encrypted sync server for the Wispie music player.
The server stores opaque encrypted blobs; it cannot read your data.
Default public instance: `https://wispie-api.gru0.dev/`.

Status: accounts and auth (`/v1/info`, `/v1/auth/*`, `/v1/account*`) are implemented.
Sync storage (`/v1/sync/*`) arrives in the next phase. Design: `plan_sync.md` in the repo root.

## Run

```
docker compose -f docker-compose.example.yml up -d --build
```

Edit `Caddyfile.example` for your domain. Or run directly:

```
go build -o wispie-server ./cmd/wispie-server
WISPIE_DATA_DIR=./data ./wispie-server            # serve
WISPIE_DATA_DIR=./data ./wispie-server stats      # accounts: N, storage: X MiB
```

Terminate TLS in front of it (Caddy example included). Clients refuse plain `http://` except for localhost/private IPs.

## Configuration (environment)

| Variable | Default | Meaning |
| --- | --- | --- |
| `WISPIE_ADDR` | `:8080` | listen address |
| `WISPIE_DATA_DIR` | `./data` | SQLite DB, blobs, `secret` (auto-generated, keep it) |
| `WISPIE_REGISTRATION` | `open` | `open` or `closed` |
| `WISPIE_TRUSTED_PROXIES` | empty | comma list of IPs/CIDRs whose `X-Forwarded-For` is trusted |
| `WISPIE_POW_BITS` | `22` | registration proof-of-work difficulty (leading zero bits) |
| `WISPIE_QUOTA_MB` | `50` | per-account storage quota |
| `WISPIE_GLOBAL_STORAGE_CAP_MB` | `5120` | server-wide cap across all accounts, e.g. `5120` for 5 GB; once reached, writes that grow storage fail with a generic "server is full" message (cap not disclosed) |
| `WISPIE_INACTIVE_DAYS` | `0` | delete accounts idle this long (0 = off) |
| `WISPIE_RL_GLOBAL_PER_MIN` / `_BURST` | `120` / `30` | per-IP global limit |
| `WISPIE_RL_REGISTER_PER_HOUR` / `_PER_DAY` / `_GLOBAL_PER_HOUR` | `5` / `20` / `200` | registration start limits |
| `WISPIE_RL_LOGIN_PER_MIN` | `20` | per-IP prelogin/login/refresh |
| `WISPIE_RL_RECOVER_IP_PER_HOUR` / `_USER_PER_DAY` | `5` / `5` | recovery attempts |
| `WISPIE_RL_SYNC_PER_MIN` / `_DELTA_PUSH_PER_MIN` | `120` / `30` | per-account sync limits |

Login failures per username trigger an exponential lockout (30 s up to 15 min) after 5 attempts; it is temporary, so nobody can be permanently locked out.

## Wire encoding

Binary fields in JSON (`salt`, `auth_key`, `recovery_auth`, `wrapped_by_*`, tokens) are base64url without padding.
`account_id` is 32 lowercase hex characters (16 bytes). `register/finish` also echoes the PoW `pow_challenge`
(returned by `register/begin`), which is HMAC-bound to the account id, so the server keeps no PoW state.
KDF parameters: `{"alg":"argon2id","m_kib":65536,"t":3,"p":1}`, accepted ranges m 32-256 MiB, t 2-10, p 1-4.

## Privacy

The server can see: number of accounts, usernames, per-account storage bytes,
blob count and (padded) sizes, day-granularity created/last-active dates, number of active sessions.

It never sees: passwords, encryption keys, songs, stats, playlists, settings or device names.

Measures: Padme padding of blobs; dates stored rounded to the day; client IPs are never written to disk or logs
(rate limiters keep them in memory only, keyed by `HMAC(daily-rotating secret, ip)`); access logs contain only
route pattern, status and duration. Sessions store only SHA-256 of tokens. Passwords never reach the server:
it stores `Argon2id(auth_key)` where `auth_key` is derived client-side from the password.
