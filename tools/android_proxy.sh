#!/bin/bash
# Runs the resolver proxy the Android emulator uses for *.test hosts, for the "Android: Start proxy" task that runs on folder open.
# If our resolver proxy is already listening on PROXY_PORT, it does nothing; another process on that port is an error.
# Otherwise it runs the proxy in the foreground, so the task owns it and it stops when the task is terminated.
# It writes the same pid file as android_emulator.sh, so that script's stop still clears this proxy.
set -euo pipefail
cd "$(dirname "$0")/.."

PROXY_PORT="${PROXY_PORT:-8899}"
STATE_DIR="${TMPDIR:-/tmp}/uptick-android"
mkdir -p "$STATE_DIR"

proxy_listener_pid() {
  lsof -nP -iTCP:"$PROXY_PORT" -sTCP:LISTEN -t 2>/dev/null | head -1 || true
}

pid="$(proxy_listener_pid)"
if [ -n "$pid" ]; then
  if ps -o command= -p "$pid" | grep -q 'tools/resolver_proxy.py'; then
    echo "Resolver proxy already running on $PROXY_PORT (pid $pid); skipping"
    echo "$pid" >"$STATE_DIR/resolver_proxy.pid"
    exit 0
  fi
  echo "Port $PROXY_PORT is in use by $(ps -o comm= -p "$pid") (pid $pid), not the resolver proxy; stop it or set PROXY_PORT" >&2
  exit 1
fi

echo "$$" >"$STATE_DIR/resolver_proxy.pid"
echo "Starting resolver proxy on $PROXY_PORT"
exec python3 tools/resolver_proxy.py "$PROXY_PORT"
