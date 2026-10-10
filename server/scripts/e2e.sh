#!/usr/bin/env bash
# Runs the real server on a temp dir and the Dart e2e test against it.
# Low PoW bits and relaxed limits keep the run fast; never use these in production.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"
TMP="$(mktemp -d)"
PORT="${WISPIE_E2E_PORT:-18080}"
go build -o "$TMP/wispie-server" ./cmd/wispie-server
WISPIE_ADDR="127.0.0.1:$PORT" WISPIE_DATA_DIR="$TMP/data" WISPIE_POW_BITS=8 \
  WISPIE_RL_GLOBAL_PER_MIN=100000 WISPIE_RL_GLOBAL_BURST=100000 \
  WISPIE_RL_REGISTER_PER_HOUR=1000 WISPIE_RL_REGISTER_PER_DAY=1000 \
  WISPIE_RL_REGISTER_GLOBAL_PER_HOUR=1000 WISPIE_RL_LOGIN_PER_MIN=1000 \
  WISPIE_RL_SYNC_PER_MIN=100000 WISPIE_RL_DELTA_PUSH_PER_MIN=100000 \
  "$TMP/wispie-server" >"$TMP/server.log" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true; rm -rf "$TMP"' EXIT
for _ in $(seq 50); do
  curl -sf "http://127.0.0.1:$PORT/v1/info" >/dev/null && break
  sleep 0.2
done
cd "$ROOT"
WISPIE_E2E_URL="http://127.0.0.1:$PORT" flutter test test/sync_e2e_test.dart "$@"
