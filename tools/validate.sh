#!/usr/bin/env bash
# ASH&LEAD -- one-command validation.
#
# The project targets Godot 4.3+ (GL Compatibility). No editor binary is needed
# for this script: it parses every .gd with gdtoolkit, then runs the project
# checker (paths, signals/autoload members, cross-script members, duplicates).
#
#   tools/validate.sh          # parse + check
#   tools/validate.sh --lint   # also run gdlint (style, advisory)
#
# Requires: python3 + gdtoolkit  (pip install "gdtoolkit==4.*")
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0

if ! command -v gdparse >/dev/null 2>&1; then
	echo "gdparse not found -- installing gdtoolkit..."
	python3 -m pip install --quiet --break-system-packages "gdtoolkit==4.*" || {
		echo "FATAL: cannot install gdtoolkit"
		exit 1
	}
fi

echo "== parsing $(find src -name '*.gd' | wc -l) scripts"
while IFS= read -r f; do
	out=$(gdparse "$f" 2>&1)
	if [ -n "$out" ]; then
		echo "PARSE FAIL: $f"
		echo "$out" | head -12
		fail=1
	fi
done < <(find src -name '*.gd')

echo "== project checks"
python3 tools/check_project.py || fail=1

echo "== shaders"
python3 - <<'PY'
import glob, re, sys
bad = 0
for path in sorted(glob.glob("shaders/*.gdshader")):
    src = open(path, encoding="utf-8").read()
    for open_ch, close_ch in (("{", "}"), ("(", ")")):
        if src.count(open_ch) != src.count(close_ch):
            print("IMBALANCED %s: %s" % (path, open_ch))
            bad = 1
    if "void fragment" not in src:
        print("NO FRAGMENT %s" % path)
        bad = 1
    for uniform in re.findall(r"uniform\s+\w+\s+(\w+)", src):
        if src.count(uniform) < 2:
            print("UNUSED UNIFORM %s: %s" % (path, uniform))
            bad = 1
print("%d shaders checked" % len(glob.glob("shaders/*.gdshader")))
sys.exit(bad)
PY
[ $? -ne 0 ] && fail=1

echo "== scenes"
for s in scenes/*.tscn; do
	while IFS= read -r ref; do
		path=${ref#*path=\"}
		path=${path%%\"*}
		if [ ! -f "${path#res://}" ]; then
			echo "MISSING in $s: $path"
			fail=1
		fi
	done < <(grep -o 'path="res://[^"]*"' "$s")
done

if [ "${1:-}" = "--lint" ]; then
	echo "== gdlint (advisory)"
	for f in $(find src -name '*.gd'); do
		gdlint "$f" 2>&1 | grep -E "^src.*Error" | head -3
	done
fi

if [ "$fail" -eq 0 ]; then
	echo "OK -- project is consistent"
else
	echo "FAILED"
fi
exit $fail
