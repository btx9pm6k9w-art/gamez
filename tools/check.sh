#!/usr/bin/env bash
# Checks that work anywhere, with or without a GPU:
#  1. gdparse on every GDScript file (needs: pip install "gdtoolkit==4.*")
#  2. tools/shadow_check.py: local variable redeclarations Godot rejects
#  3. if Godot is installed, a headless start that compiles every script and
#     shader and quits; any SCRIPT ERROR or SHADER ERROR fails the check.
set -uo pipefail
cd "$(dirname "$0")/.."
status=0

if command -v gdparse >/dev/null; then
	echo "== gdparse"
	while IFS= read -r f; do
		gdparse "$f" >/dev/null || { echo "FAIL $f"; status=1; }
	done < <(git ls-files '*.gd')
else
	# The headless Godot run below parses every script too, so a missing
	# gdparse only fails the check when Godot is missing as well.
	echo "warning: gdparse not installed (pip install \"gdtoolkit==4.*\")"
	no_gdparse=1
fi

echo "== shadow check"
python3 tools/shadow_check.py scripts || status=1

GODOT_BIN=""
for g in "${GODOT:-}" /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" "$(command -v godot || true)" "$(command -v godot4 || true)"; do
	if [ -n "$g" ] && [ -x "$g" ]; then GODOT_BIN="$g"; break; fi
done
if [ -n "$GODOT_BIN" ]; then
	echo "== headless run with $("$GODOT_BIN" --version | head -n1)"
	log=$(mktemp)
	if ! "$GODOT_BIN" --headless --path . --import >"$log" 2>&1; then
		echo "FAIL: import exited with an error (log: $log)"
		status=1
	fi
	if ! "$GODOT_BIN" --headless --path . --quit-after 300 >>"$log" 2>&1; then
		echo "FAIL: the game exited with an error (log: $log)"
		status=1
	fi
	if grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|Failed to load|Failed loading|Compile Error|ERROR: .*res://" "$log"; then
		echo "FAIL: errors in the Godot output (full log: $log)"
		status=1
	else
		echo "No script or shader errors."
	fi
else
	echo "Godot not found; skipping the headless run."
	if [ "${no_gdparse:-0}" = 1 ]; then
		echo "FAIL: neither gdparse nor Godot is available, nothing was checked"
		status=1
	fi
fi
exit $status
