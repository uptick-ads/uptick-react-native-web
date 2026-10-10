#!/bin/bash
# Starts Metro for the VS Code "Start Metro" task, whose dependents wait for a ready line in this output.
# Expo prints "Logs for your project will appear below" once Metro is up. If a Metro is already serving 8081,
# `expo start` would instead stop at a "Use port 8082 instead?" prompt and never print that, so reuse the running one.
set -euo pipefail
cd "$(dirname "$0")/.."

# Task shells don't always run ~/.zshrc, where mise activates node.
command -v npx >/dev/null || export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:$PATH"

metro_running() {
  curl -s -m 2 http://localhost:8081/status | grep -q packager-status:running
}

# The slug Metro's manifest reports, so a Metro started from another project isn't mistaken for this one.
served_slug() {
  curl -s -m 5 -H 'expo-platform: ios' http://localhost:8081/ |
    python3 -c 'import json, sys; print(json.load(sys.stdin)["extra"]["expoClient"]["slug"])' 2>/dev/null || true
}

project_slug() {
  python3 -c 'import json; print(json.load(open("app.json"))["expo"]["slug"])'
}

if metro_running; then
  serving="$(served_slug)"
  if [ "$serving" != "$(project_slug)" ]; then
    echo "Port 8081 is held by something other than this project's Metro (${serving:-unknown}); stop it, e.g. lsof -ti tcp:8081 | xargs kill, and rerun this task" >&2
    exit 1
  fi
  echo "Metro already running on 8081; using it"
  while metro_running; do
    sleep 5
  done
  echo "Metro on 8081 stopped"
  exit 0
fi

exec npx expo start "$@"
