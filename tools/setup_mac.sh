#!/usr/bin/env bash
# One-time setup on macOS: makes sure Godot 4.7 is installed, then imports the
# project once so the first run starts quickly.
set -euo pipefail
cd "$(dirname "$0")/.."

find_godot() {
	for g in "${GODOT:-}" /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot" "$(command -v godot || true)"; do
		if [ -n "$g" ] && [ -x "$g" ]; then echo "$g"; return 0; fi
	done
	return 1
}

if ! GODOT_BIN=$(find_godot); then
	if command -v brew >/dev/null; then
		echo "Installing Godot with Homebrew..."
		brew install --cask godot
		GODOT_BIN=$(find_godot)
	else
		echo "Godot not found. Install Godot 4.7 (standard, not .NET) from https://godotengine.org/download/macos"
		echo "or install Homebrew (https://brew.sh) and run this script again."
		exit 1
	fi
fi

VERSION=$("$GODOT_BIN" --version | head -n1)
echo "Using Godot $VERSION at $GODOT_BIN"
case "$VERSION" in
	4.7*|4.8*|4.9*) ;;
	*) echo "Warning: this project targets Godot 4.7 or newer; found $VERSION." ;;
esac

echo "Importing the project (first time only takes a minute)..."
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
echo "Done. Run ./tools/run.sh to play."
