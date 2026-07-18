#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-godot}"
port="${BRINDLE_LOCAL_PORT:-7073}"

if ! command -v "$godot_bin" >/dev/null; then
	if [[ -z "${GODOT_BIN:-}" ]] && command -v godot4 >/dev/null; then
		godot_bin="godot4"
	else
		echo "Godot was not found. Set GODOT_BIN to your Godot 4 executable." >&2
		exit 1
	fi
fi

"$godot_bin" --headless --path . -- --server --port "$port" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT INT TERM

sleep 1
if ! kill -0 "$server_pid" 2>/dev/null; then
	echo "Local server exited during startup." >&2
	exit 1
fi
BRINDLE_SERVER_URL="ws://127.0.0.1:$port" "$godot_bin" --path .
