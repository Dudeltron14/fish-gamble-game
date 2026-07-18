#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-godot}"
port="${BRINDLE_LOCAL_PORT:-7073}"

"$godot_bin" --headless --path . -- --server --port "$port" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT INT TERM

sleep 1
BRINDLE_SERVER_URL="ws://127.0.0.1:$port" "$godot_bin" --path .
