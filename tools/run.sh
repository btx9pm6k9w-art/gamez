#!/usr/bin/env bash
# Runs the game. Set GODOT=/path/to/Godot to use a specific build.
set -euo pipefail
cd "$(dirname "$0")/.."
for g in "${GODOT:-}" /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot" "$(command -v godot || true)"; do
	if [ -n "$g" ] && [ -x "$g" ]; then exec "$g" --path . "$@"; fi
done
echo "Godot not found. Run ./tools/setup_mac.sh first, or set GODOT=/path/to/Godot."
exit 1
