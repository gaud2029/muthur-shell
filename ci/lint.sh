#!/usr/bin/env bash
# Static checks on everything tracked: QML syntax, shell scripts, Python
# helpers, the typing-sound player. Reports every failure, exits 1 if any.
#
#   ci/lint.sh
#
# qmllint only fails on syntax errors here: its type warnings don't apply
# to this config (singletons without a qmldir, Quickshell types), and
# ci/load-test.sh catches what a real load would.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

failed=0
check() {
    local name=$1; shift
    if "$@"; then echo "ok    $name"; else echo "FAIL  $name"; failed=1; fi
}

# Tracked files only, sorted by kind from the extension or the shebang.
qml=() sh=() py=()
while IFS= read -r f; do
    case $f in
        *.qml) qml+=("$f"); continue ;;
        *.sh) sh+=("$f"); continue ;;
        *.py) py+=("$f"); continue ;;
        dotfiles/bash/*) sh+=("$f"); continue ;;
    esac
    case $(head -n 1 "$f" 2>/dev/null) in
        '#!'*bash*|'#!/bin/sh'*) sh+=("$f") ;;
        '#!'*python*) py+=("$f") ;;
    esac
done < <(git ls-files)

qmllint=$(command -v qmllint || command -v qmllint6 || echo /usr/lib/qt6/bin/qmllint)
qml_syntax() {
    # Exit status is 0 with warnings, non-zero on a syntax error.
    "$qmllint" "${qml[@]}" 2>&1 | grep -A 3 '\[syntax\]'
    [[ ${PIPESTATUS[0]} -eq 0 ]]
}
check "qmllint: ${#qml[@]} QML files" qml_syntax

for f in "${sh[@]}"; do
    check "bash -n $f" bash -n "$f"
done
if command -v shellcheck > /dev/null; then
    # Errors only: the scripts' style is theirs.
    check "shellcheck: ${#sh[@]} scripts" shellcheck -S error -s bash "${sh[@]}"
else
    echo "skip  shellcheck (not installed)"
fi

py_syntax() {
    # ast.parse rather than py_compile: no __pycache__ left behind.
    python3 -c 'import ast, sys
for f in sys.argv[1:]:
    ast.parse(open(f, encoding="utf-8").read(), f)' "$@"
}
check "python: ${#py[@]} files" py_syntax "${py[@]}"

if pkg-config --exists libpipewire-0.3; then
    # shellcheck disable=SC2046
    check "gcc: muthur-keysound.c" gcc -fsyntax-only -Wall -Werror \
        $(pkg-config --cflags libpipewire-0.3) dotfiles/keysound/muthur-keysound.c
else
    echo "skip  muthur-keysound.c (no libpipewire-0.3)"
fi

exit $failed
