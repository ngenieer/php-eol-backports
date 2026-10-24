#!/usr/bin/env bash
# Build PHP twice (unpatched / patched) and diff the results of PHP's own test suite.
# A backport passes only when no test that passes on the unpatched build fails on the patched one.
# Usage: scripts/compare-tests.sh <clean-php-source-dir> [workdir]
set -euo pipefail

SRC="$(cd "${1:?usage: compare-tests.sh <clean-php-source-dir> [workdir]}" && pwd)"
WORK="${2:-$(mktemp -d)}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SUITES="Zend/tests tests main ext/session ext/standard/tests/file ext/standard/tests/strings"
CFLAGS_COMPAT="-O2 -fcommon -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion"

build () {
  local dir="$1"
  ( cd "$dir"
    [ -x configure ] || ./buildconf --force >/dev/null 2>&1
    CFLAGS="$CFLAGS_COMPAT" ./configure --disable-all --enable-session --enable-cli --enable-cgi --disable-phpdbg >config.out 2>&1
    make -j"$(nproc)" >make.out 2>&1 )
}

runtests () {
  local dir="$1"
  ( cd "$dir"
    TEST_PHP_EXECUTABLE=sapi/cli/php TEST_PHP_CGI_EXECUTABLE=sapi/cgi/php-cgi NO_INTERACTION=1 \
      sapi/cli/php run-tests.php -p sapi/cli/php -q --set-timeout 60 $SUITES >runtests.out 2>&1 || true
    # failed test paths, taken from the FAILED TEST SUMMARY block
    sed -n '/^FAILED TEST SUMMARY/,/^=====/p' runtests.out | grep -oE '\[[^]]+\.phpt\]' | tr -d '[]' | sort -u > failed.txt )
}

cp -a "$SRC" "$WORK/base"; cp -a "$SRC" "$WORK/fix"
"$REPO/scripts/apply.sh" "$WORK/fix"
build "$WORK/base" & build "$WORK/fix" & wait
# run sequentially: timing-sensitive tests (e.g. timeout_*) flake when both suites share the CPU
runtests "$WORK/base"
runtests "$WORK/fix"

for d in base fix; do echo "== $d"; grep -E '^Tests (passed|failed)' "$WORK/$d/runtests.out"; done
echo "== failing only after the patch:"
comm -13 "$WORK/base/failed.txt" "$WORK/fix/failed.txt" | tee "$WORK/regressions.txt"
echo "Compare this list with EXPECTED-CHANGES.md; anything not listed there is a porting error."
