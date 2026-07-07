#!/usr/bin/env bash
set -euo pipefail

cd "/Users/deletoe/workspace/codex-web"
export PATH="/opt/homebrew/bin:/Applications/Codex.app/Contents/Resources:/usr/bin:/bin:/usr/sbin:/sbin"
export CODEX_BIN="/Applications/Codex.app/Contents/Resources/codex"

while true; do
  rm -f codex-web-app-server.sock

  "$CODEX_BIN" app-server --listen unix://./codex-web-app-server.sock >> codex-app-server.log 2>&1 &
  app_server_pid=$!
  echo "$app_server_pid" > codex-app-server.pid

  for _ in {1..50}; do
    [[ -S codex-web-app-server.sock ]] && break
    sleep 0.1
  done

  CODEX_CLI_PATH="/Users/deletoe/workspace/codex-web/codex-web-proxy" \
    node src/server/main.js --host 10.130.92.166 --port 8214 >> codex-web.log 2>&1 &
  web_pid=$!
  echo "$web_pid" > codex-web.pid

  wait "$web_pid" || true
  kill "$app_server_pid" 2>/dev/null || true
  wait "$app_server_pid" 2>/dev/null || true

  sleep 1
done
