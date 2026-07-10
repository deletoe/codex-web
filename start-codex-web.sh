#!/usr/bin/env bash
set -euo pipefail

ROOT="${CODEX_WEB_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
HOST="${CODEX_WEB_HOST:-10.130.92.166}"
PORT="${CODEX_WEB_PORT:-8214}"

resolve_codex_bin() {
  local candidate
  if [[ -n "${CODEX_BIN:-}" ]]; then
    if [[ -x "$CODEX_BIN" ]]; then
      printf '%s\n' "$CODEX_BIN"
      return
    fi
    echo "Ignoring unavailable CODEX_BIN: $CODEX_BIN" >&2
  fi

  for candidate in \
    "/Applications/ChatGPT.app/Contents/Resources/codex" \
    "/Applications/Codex.app/Contents/Resources/codex" \
    "$ROOT/node_modules/.bin/codex"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  if command -v codex >/dev/null 2>&1; then
    command -v codex
    return
  fi

  echo "Unable to find a Codex CLI. Set CODEX_BIN to an executable path." >&2
  exit 127
}

cd "$ROOT"
export PATH="/opt/homebrew/bin:/Applications/ChatGPT.app/Contents/Resources:/Applications/Codex.app/Contents/Resources:/usr/bin:/bin:/usr/sbin:/sbin"
CODEX_BIN="$(resolve_codex_bin)"
export CODEX_BIN

while true; do
  rm -f codex-web-app-server.sock

  "$CODEX_BIN" app-server --listen unix://./codex-web-app-server.sock >> codex-app-server.log 2>&1 &
  app_server_pid=$!
  echo "$app_server_pid" > codex-app-server.pid

  for _ in {1..50}; do
    [[ -S codex-web-app-server.sock ]] && break
    sleep 0.1
  done

  CODEX_CLI_PATH="$ROOT/codex-web-proxy" \
    node src/server/main.js --host "$HOST" --port "$PORT" >> codex-web.log 2>&1 &
  web_pid=$!
  echo "$web_pid" > codex-web.pid

  wait "$web_pid" || true
  kill "$app_server_pid" 2>/dev/null || true
  wait "$app_server_pid" 2>/dev/null || true

  sleep 1
done
