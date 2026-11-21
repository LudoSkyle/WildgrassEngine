#!/bin/bash
# Runs the engine tests headless. Usage: tools/run_tests.sh [res://tests/path]
# GODOT: the Godot 4.7 binary (default: "godot" from PATH).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-godot}"
target="${1:-res://tests}"

if [ ! -f "$root/addons/gdUnit4/plugin.cfg" ]; then
	echo "gdUnit4 is missing: run tools/install_gdunit4.sh first." >&2
	exit 1
fi

# An editor open on this folder imports by itself; a second import would fight it.
editor_open() {
	local pid
	for pid in $(ps -axo pid=,command= | awk '/Godot/ && /--editor/ {print $1}'); do
		[ "$(lsof -a -p "$pid" -d cwd -Fn 2> /dev/null | sed -n 's/^n//p')" = "$root" ] && return 0
		ps -o command= -p "$pid" | grep -q -- "--path $root" && return 0
	done
	return 1
}

if editor_open; then
	echo "An editor is open on this project: it imports, the tests use its state."
else
	"$godot" --headless --path "$root" --import > /dev/null 2>&1 || true
fi
# A remote debugger nobody listens to: a script error fails the test instead of
# stopping at the console debugger prompt forever.
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
status=0
"$godot" --headless --path "$root" -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	-a "$target" -c --ignoreHeadlessMode -- --test 2>&1 | tee "$log" || status=$?

# Godot only warns about objects left alive at exit: fail on it.
if grep -q "leaked at exit" "$log"; then
	echo "Objects leaked at exit: run Godot with --verbose to name them." >&2
	[ "$status" -ne 0 ] || status=1
fi
exit "$status"
