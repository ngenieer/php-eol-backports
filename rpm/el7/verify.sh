#!/usr/bin/env bash
# Verify rebuilt Remi php73 RPMs on CentOS 7.
#   A) upgrade path: install Remi's current EL7 packages (7.3.33-14) from the remi-php73 repo,
#      smoke-test, upgrade in place to the patched RPMs with yum, smoke-test again
#   B) regression: PHP test suites on unpatched (22.base0) vs patched (22.sizlon1) RPMs
#      built from the same Remi 7.3.33-22 source
# Usage: rpm/el7/verify.sh <rpm-dir with base/ and fix/> <php source tree with tests> <out-dir>
set -u
RPMS="$(cd "$1" && pwd)"; SRC="$(cd "$2" && pwd)"; OUT="$3"; mkdir -p "$OUT"
IMG=peb-el7-runtime
PKGS="php-cli php-common php-fpm php-mysqlnd php-pdo php-gd php-opcache php-mbstring php-xml php-json"
SUITES="Zend/tests tests main ext/session ext/standard/tests/file ext/standard/tests/strings ext/standard/tests/array ext/opcache/tests"

echo "## A) yum upgrade from Remi 7.3.33-14"
docker run --rm -v "$RPMS:/rpms:ro" $IMG bash -c "
  yum -q -y --enablerepo=remi-php73 install $PKGS >/tmp/i.log 2>&1 || { tail /tmp/i.log; exit 1; }
  echo before: \$(rpm -q php-cli)
  /smoke/run.sh > /tmp/smoke-before.txt 2>&1; pkill -f php-fpm; sleep 1
  files=\$(for p in \$(rpm -qa --qf '%{NAME}\n' 'php*'); do ls /rpms/fix/\$p-7.3.33-*.x86_64.rpm 2>/dev/null; done)
  yum -q -y localinstall \$files >/tmp/u.log 2>&1 || { tail /tmp/u.log; exit 1; }
  echo after: \$(rpm -q php-cli); php -v | head -1
  rpm -q --changelog php-common | head -3
  /smoke/run.sh > /tmp/smoke-after.txt 2>&1
  echo '-- smoke differences (Remi -14 < > patched):'; diff /tmp/smoke-before.txt /tmp/smoke-after.txt | grep '^[<>]'
  cat /tmp/smoke-after.txt
" | tee "$OUT/upgrade.txt"

echo "## B) test suites, same source with and without the patch"
for t in base fix; do
  docker run --rm -v "$RPMS:/rpms:ro" -v "$SRC:/src:ro" $IMG bash -c "
    files=\$(for p in $PKGS; do ls /rpms/$t/\$p-7.3.33-*.x86_64.rpm; done)
    yum -q -y localinstall \$files >/tmp/i.log 2>&1 || { tail /tmp/i.log >&2; exit 1; }
    cp -a /src /tmp/src && cd /tmp/src
    TEST_PHP_EXECUTABLE=/usr/bin/php NO_INTERACTION=1 /usr/bin/php run-tests.php -p /usr/bin/php -q --set-timeout 60 $SUITES > /tmp/rt.out 2>&1
    grep -E '^Tests (passed|failed)' /tmp/rt.out >&2
    sed -n '/^FAILED TEST SUMMARY/,/^=====/p' /tmp/rt.out | grep -oE '\[[^]]+\.phpt\]' | tr -d '[]' | sort -u
  " > "$OUT/failed-$t.txt" 2> "$OUT/summary-$t.txt"
  echo "$t: $(tr '\n' ' ' < "$OUT/summary-$t.txt" | tr -s ' ')"
done
echo "-- tests failing only after the patch:"
comm -13 "$OUT/failed-base.txt" "$OUT/failed-fix.txt" | tee "$OUT/regressions.txt"
