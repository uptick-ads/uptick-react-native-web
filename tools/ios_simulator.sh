#!/bin/bash
# Starts or stops the iOS simulator for the demo, together with what the local Uptick API needs.
# start: boots the simulator (IOS_DEVICE="iPhone 18 Pro" by default), opens its window and trusts puma-dev's CA,
#   then stays in the foreground until the simulator shuts down or the script is interrupted, and shuts it down on the way out.
# open [path]: waits for Metro, installs Expo Go from Expo CLI's cache if the simulator lacks it, and opens the app (e.g. open "/--/?target=popup").
# stop: shuts the simulator down.
# Unlike Android, no proxy or dev build is needed: the simulator resolves *.test through the host, and Expo Go's WebView trusts the simulator keychain.
set -euo pipefail
cd "$(dirname "$0")/.."

# simctl needs full Xcode; fall back to it when xcode-select still points at the standalone Command Line Tools.
if [ -z "${DEVELOPER_DIR:-}" ] && [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools* ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

IOS_DEVICE="${IOS_DEVICE:-iPhone 18 Pro}"
PUMA_DEV_CA="${PUMA_DEV_CA:-$HOME/Library/Application Support/io.puma.dev/cert.pem}"

device_udid() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["name"] == name:
            print(d["udid"])
            sys.exit()
' "$IOS_DEVICE"
}

is_booted() {
  xcrun simctl list devices booted | grep -q "$1"
}

# Xcode 27 replaced Simulator.app with DeviceHub.app.
open_simulator_window() {
  local xcode="${DEVELOPER_DIR:-$(xcode-select -p)}/../.."
  for app in "$xcode/Contents/Developer/Applications/Simulator.app" "$xcode/Contents/Applications/DeviceHub.app"; do
    [ -d "$app" ] && { open "$app"; return; }
  done
}

start() {
  UDID="$(device_udid)"
  [ -n "$UDID" ] || { echo "No available simulator named \"$IOS_DEVICE\"; see xcrun simctl list devices available" >&2; exit 1; }

  if ! is_booted "$UDID"; then
    echo "Booting $IOS_DEVICE"
    xcrun simctl boot "$UDID"
  fi
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  open_simulator_window

  if [ -f "$PUMA_DEV_CA" ]; then
    xcrun simctl keychain "$UDID" add-root-cert "$PUMA_DEV_CA"
  fi

  echo "$IOS_DEVICE ($UDID) ready: with Metro running, open the app with  tools/ios_simulator.sh open"

  while is_booted "$UDID"; do
    sleep 2
  done
  echo "Simulator shut down"
}

open_app() {
  UDID="$(device_udid)"
  is_booted "$UDID" || { echo "$IOS_DEVICE isn't booted; run the iOS: Start simulator task" >&2; exit 1; }

  for _ in $(seq 1 60); do
    curl -s -m 2 http://localhost:8081/status | grep -q running && break
    sleep 1
  done
  curl -s -m 2 http://localhost:8081/status | grep -q running || { echo "Metro isn't running on 8081; run the Start Metro task" >&2; exit 1; }

  if ! xcrun simctl get_app_container "$UDID" host.exp.Exponent >/dev/null 2>&1; then
    local expo_go
    expo_go="$(ls -d "$HOME"/.expo/ios-simulator-app-cache/Expo-Go-*.app 2>/dev/null | sort -V | tail -1)"
    [ -n "$expo_go" ] || { echo "Expo Go isn't installed and Expo CLI hasn't cached it yet; run npx expo start --ios once" >&2; exit 1; }
    echo "Installing $(basename "$expo_go")"
    xcrun simctl install "$UDID" "$expo_go"
  fi

  xcrun simctl openurl "$UDID" "exp://127.0.0.1:8081${1:-}"
  echo "Opened the app in Expo Go on $IOS_DEVICE"
}

stop() {
  UDID="${UDID:-$(device_udid)}"
  if [ -n "$UDID" ] && is_booted "$UDID"; then
    xcrun simctl shutdown "$UDID"
    echo "Simulator stopped"
  fi
}

# Runs however start ends: Ctrl-C, VS Code terminating the task, a failed boot, or the simulator being shut down.
cleanup() {
  trap - EXIT INT TERM HUP
  stop
}

case "${1:-}" in
  start)
    trap cleanup EXIT
    trap 'exit 130' INT TERM HUP
    start
    ;;
  open) open_app "${2:-}" ;;
  stop) stop ;;
  *) echo "usage: $0 start|open [path]|stop" >&2; exit 2 ;;
esac
