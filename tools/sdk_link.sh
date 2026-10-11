#!/bin/bash
# Points the app at the local @uptick-ads/react-native-web-sdk checkout, or back at the registry copy, for the "SDK: npm link" and "SDK: npm unlink" tasks.
# link: npm link in the SDK checkout, then in this app. The SDK checkout is SDK_DIR, ../react-native-web-sdk by default.
# unlink: remove the app's link, then npm install to restore the registry copy pinned in package-lock.json.
# Metro caches the old resolution, so after either this stops any Metro on 8081 and runs tools/metro.sh --clear in its place.
# That keeps this task's terminal as the Metro server, so the task is a background task that ends when Metro does.
set -euo pipefail
cd "$(dirname "$0")/.."

PACKAGE="@uptick-ads/react-native-web-sdk"
SDK_DIR="${SDK_DIR:-$(cd .. && pwd)/react-native-web-sdk}"

# Stops whatever holds 8081 and waits for it to close, so metro.sh doesn't reuse the stale Metro.
stop_metro() {
  local pid
  pid="$(lsof -nP -iTCP:8081 -sTCP:LISTEN -t 2>/dev/null | head -1 || true)"
  [ -n "$pid" ] || return 0
  echo "Stopping Metro (pid $pid) to restart it with --clear"
  kill "$pid"
  for _ in $(seq 1 20); do
    lsof -nP -iTCP:8081 -sTCP:LISTEN -t >/dev/null 2>&1 || return 0
    sleep 0.5
  done
  echo "Metro is still holding 8081; stop it and rerun this task" >&2
  exit 1
}

restart_metro() {
  stop_metro
  exec tools/metro.sh --clear
}

link() {
  [ -f "$SDK_DIR/package.json" ] || { echo "No SDK checkout at $SDK_DIR; set SDK_DIR" >&2; exit 1; }
  (cd "$SDK_DIR" && npm link)
  npm link "$PACKAGE"
  echo "Linked $PACKAGE from $SDK_DIR"
  restart_metro
}

unlink() {
  npm unlink "$PACKAGE" --no-save || true
  npm install
  echo "Restored the registry copy of $PACKAGE"
  restart_metro
}

case "${1:-}" in
  link) link ;;
  unlink) unlink ;;
  *) echo "usage: $0 link|unlink" >&2; exit 2 ;;
esac
