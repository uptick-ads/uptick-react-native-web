#!/bin/bash
# Starts or stops the Android emulator for the demo, together with what the local Uptick API needs.
# start: boots the AVD (AVD=Pixel_10a by default), forwards Metro's port, runs tools/resolver_proxy.py and points the emulator at it,
#   then stays in the foreground streaming the proxy log until the emulator exits or the script is interrupted, and stops everything on the way out.
# stop: clears the emulator's proxy setting first (it has no network while the setting outlives the proxy), then stops the proxy and the emulator.
set -euo pipefail
cd "$(dirname "$0")/.."
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"

AVD="${AVD:-Pixel_10a}"
PROXY_PORT="${PROXY_PORT:-8899}"
# The emulator's console port fixes its adb serial, so every adb call targets this emulator even with a phone or another emulator attached.
EMULATOR_PORT="${EMULATOR_PORT:-5554}"
export ANDROID_SERIAL="emulator-$EMULATOR_PORT"
STATE_DIR="${TMPDIR:-/tmp}/uptick-android"
mkdir -p "$STATE_DIR"

emulator_running() {
  adb devices | grep -q "^$ANDROID_SERIAL[[:space:]]device$"
}

start() {
  if ! emulator_running; then
    echo "Booting $AVD as $ANDROID_SERIAL"
    nohup emulator -avd "$AVD" -port "$EMULATOR_PORT" >"$STATE_DIR/emulator.log" 2>&1 &
  fi
  adb wait-for-device
  for _ in $(seq 1 120); do
    [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] && break
    sleep 2
  done
  [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ] || { echo "Emulator did not finish booting; see $STATE_DIR/emulator.log"; exit 1; }

  adb reverse tcp:8081 tcp:8081 >/dev/null

  if ! lsof -nP -iTCP:"$PROXY_PORT" -sTCP:LISTEN >/dev/null; then
    nohup python3 tools/resolver_proxy.py "$PROXY_PORT" >"$STATE_DIR/resolver_proxy.log" 2>&1 &
    echo $! >"$STATE_DIR/resolver_proxy.pid"
    sleep 1
  fi
  adb shell settings put global http_proxy "10.0.2.2:$PROXY_PORT"

  echo "$ANDROID_SERIAL ready: Metro on 8081 forwarded, proxy 10.0.2.2:$PROXY_PORT (log: $STATE_DIR/resolver_proxy.log)"

  tail -n 0 -f "$STATE_DIR/resolver_proxy.log" &
  TAIL_PID=$!
  while emulator_running; do
    sleep 2
  done
  echo "Emulator exited"
}

# Runs however start ends: Ctrl-C, VS Code terminating the task, a failed boot, or the emulator being closed.
cleanup() {
  trap - EXIT INT TERM HUP
  [ -n "${TAIL_PID:-}" ] && kill "$TAIL_PID" 2>/dev/null
  stop
}

stop() {
  if emulator_running; then
    adb shell settings put global http_proxy :0
    adb emu kill >/dev/null
    # adb keeps listing the device while it shuts down, which would make an immediate `start` skip the boot.
    for _ in $(seq 1 30); do
      emulator_running || break
      sleep 1
    done
    echo "Emulator stopped"
  fi
  if [ -f "$STATE_DIR/resolver_proxy.pid" ]; then
    kill "$(cat "$STATE_DIR/resolver_proxy.pid")" 2>/dev/null || true
    rm -f "$STATE_DIR/resolver_proxy.pid"
    echo "Resolver proxy stopped"
  fi
}

case "${1:-}" in
  start)
    trap cleanup EXIT
    trap 'exit 130' INT TERM HUP
    start
    ;;
  stop) stop ;;
  *) echo "usage: $0 start|stop" >&2; exit 2 ;;
esac
