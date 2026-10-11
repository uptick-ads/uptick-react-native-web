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

# The slug Metro's manifest reports, so a Metro started from another project isn't mistaken for this one.
served_slug() {
  curl -s -m 5 -H 'expo-platform: ios' http://localhost:8081/ |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["extra"]["expoClient"]["slug"])' 2>/dev/null || true
}

project_slug() {
  python3 -c 'import json; print(json.load(open("app.json"))["expo"]["slug"])'
}

metro_running() {
  curl -s -m 2 http://localhost:8081/status | grep -q packager-status:running
}

# Refuses before anything changes unless whatever holds 8081 is this project's Metro, the same check metro.sh makes.
check_metro() {
  local pid serving
  pid="$(lsof -nP -iTCP:8081 -sTCP:LISTEN -t 2>/dev/null | head -1 || true)"
  [ -n "$pid" ] || return 0
  serving="$(served_slug)"
  if ! metro_running || [ "$serving" != "$(project_slug)" ]; then
    echo "Port 8081 is held by something other than this project's Metro (${serving:-unknown}); stop it and rerun this task" >&2
    exit 1
  fi
}

# Stops this project's Metro, checked by check_metro, and waits for 8081 to close, so metro.sh doesn't reuse the stale Metro.
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
  check_metro
  [ -f "$SDK_DIR/package.json" ] || { echo "No SDK checkout at $SDK_DIR; set SDK_DIR" >&2; exit 1; }
  (cd "$SDK_DIR" && npm link)
  npm link "$PACKAGE"
  echo "Linked $PACKAGE from $SDK_DIR"
  restart_metro
}

unlink() {
  check_metro
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
