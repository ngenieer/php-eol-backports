#!/usr/bin/env bash
# For each version: build base/fix images from the official php:<ver>-fpm image,
# run PHP's test suites in each (sequentially), run the FPM smoke test in each,
# and report differences.
# Usage: docker/verify.sh [versions...]   (default: 7.3 7.2 7.1 7.0)
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$REPO/docker/results}"
mkdir -p "$OUT"
VERSIONS="${*:-7.3 7.2 7.1 7.0}"

for v in $VERSIONS; do
  echo "######## PHP $v"
  for t in base fix; do
    p=0; [ "$t" = fix ] && p=1
    if ! docker build -q -f "$REPO/docker/Dockerfile" --build-arg PHPVER="$v" --build-arg PATCH=$p \
         -t "peb:$v-$t" "$REPO" > "$OUT/build-$v-$t.log" 2>&1; then
      echo "build $v-$t FAILED (see $OUT/build-$v-$t.log)"; continue 2
    fi
  done
  for t in base fix; do
    docker run --rm "peb:$v-$t" /tests.sh > "$OUT/failed-$v-$t.txt" 2> "$OUT/summary-$v-$t.txt"
    echo "$t: $(tr '\n' ' ' < "$OUT/summary-$v-$t.txt" | tr -s ' ')"
  done
  echo "-- tests failing only after the patch:"
  comm -13 "$OUT/failed-$v-base.txt" "$OUT/failed-$v-fix.txt" | tee "$OUT/regressions-$v.txt"
  for t in base fix; do docker run --rm "peb:$v-$t" /smoke/run.sh > "$OUT/smoke-$v-$t.txt" 2>&1; done
  echo "-- smoke differences (base < > fix):"
  diff "$OUT/smoke-$v-base.txt" "$OUT/smoke-$v-fix.txt" | grep '^[<>]'
done
