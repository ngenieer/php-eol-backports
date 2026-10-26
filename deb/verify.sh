#!/usr/bin/env bash
# Verify the rebuilt Sury php<x.y> packages from deb/build.sh.
#   A) upgrade path: install the distro's own php<x.y> packages, smoke-test, upgrade in place
#      to the rebuilt packages with apt, smoke-test again
#   B) regression: PHP test suites on base (no bailout patch) vs fix packages built from the
#      same Sury source
# Usage: deb/verify.sh <buster|bionic> <x.y> <out-dir from build.sh>
set -u
DIST="$1"; VER="$2"; OUT="$(cd "$3" && pwd)"; RES="$OUT/results"; mkdir -p "$RES"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
case "$DIST" in buster) BASE=debian:buster ;; bionic) BASE=ubuntu:18.04 ;; *) exit 1 ;; esac
IMG="peb-deb-runtime:$DIST"
docker build -q -f "$REPO/deb/Dockerfile" --build-arg BASE="$BASE" --target runtime -t "$IMG" "$REPO" >/dev/null || exit 1

# The rebuilt packages need php-common >= 1:81. Debian 10 ships 2:69 (epoch 2, fine). Ubuntu 18.04
# ships 1:60; servers that used Sury's PPA already have its 2:93. For the test, install Sury's current
# php-common (Debian's own one Breaks php7.x-common).
EXTRA=""
if [ "$DIST" = bionic ]; then
  f=php-common_101+0~20261021.78+ubuntu22.04~1.gbp53f25f_all.deb
  [ -f "$OUT/src/sury-php-common_all.deb" ] || curl -fsS -o "$OUT/src/sury-php-common_all.deb" "https://packages.sury.org/php/pool/main/p/php-defaults/${f//+/%2B}"
  echo "62bc3fbedea25bb92869c60085f094bcb68716e3ddb8c3128eb33a977f697a05  $OUT/src/sury-php-common_all.deb" | sha256sum -c --quiet || exit 1
  EXTRA=/debs/src/sury-php-common_all.deb
fi
PKGS="php$VER-cli php$VER-common php$VER-fpm php$VER-mysql php$VER-gd php$VER-opcache php$VER-mbstring php$VER-xml php$VER-json"
SUITES="Zend/tests tests main ext/session ext/standard/tests/file ext/standard/tests/strings ext/standard/tests/array ext/opcache/tests"
APT="apt-get -o Acquire::Check-Valid-Until=false -y --no-install-recommends"

echo "## A) apt upgrade from the distro php$VER"
docker run --rm -v "$OUT:/debs:ro" "$IMG" bash -c "
  $APT update >/dev/null 2>&1; $APT install $PKGS >/tmp/i.log 2>&1 || { tail /tmp/i.log; exit 1; }
  echo before: \$(dpkg-query -W -f '\${Version}' php$VER-cli)
  /smoke/run.sh > /tmp/smoke-before.txt 2>&1; pkill -f php-fpm; sleep 1
  files=\$(for p in \$(dpkg-query -W -f '\${Package}\n' 'php$VER*'); do ls /debs/fix/\${p}_*.deb 2>/dev/null; done)
  $APT install $EXTRA \$files >/tmp/u.log 2>&1 || { tail -20 /tmp/u.log; exit 1; }
  echo after: \$(dpkg-query -W -f '\${Version}' php$VER-cli); php -v | head -1
  echo not upgraded: \$(dpkg-query -W -f '\${db:Status-Abbrev} \${Package} \${Version}\n' 'php$VER*' | awk '\$1=="ii" && \$3 !~ /sizlon1/ {print \$2}' | grep . || echo none)
  /smoke/run.sh > /tmp/smoke-after.txt 2>&1
  echo '-- smoke differences (distro < > rebuilt):'; diff /tmp/smoke-before.txt /tmp/smoke-after.txt | grep '^[<>]'
  cat /tmp/smoke-after.txt
" | tee "$RES/upgrade.txt"

echo "## B) test suites, same source with and without the patch"
for t in base fix; do
  docker run --rm -v "$OUT:/debs:ro" "$IMG" bash -c "
    $APT update >/dev/null 2>&1
    files=\$(for p in $PKGS php$VER-cgi php$VER-readline; do ls /debs/$t/\${p}_*.deb; done)
    $APT install $EXTRA \$files >/tmp/i.log 2>&1 || { tail /tmp/i.log >&2; exit 1; }
    $APT install xz-utils >/dev/null 2>&1
    mkdir /tmp/src && tar xf /debs/src/php${VER}_*.orig.tar.xz -C /tmp/src --strip-components=1 && cd /tmp/src
    TEST_PHP_EXECUTABLE=/usr/bin/php$VER TEST_PHP_CGI_EXECUTABLE=/usr/bin/php-cgi$VER NO_INTERACTION=1 \
      /usr/bin/php$VER run-tests.php -p /usr/bin/php$VER -q --set-timeout 60 $SUITES > /tmp/rt.out 2>&1
    grep -E '^Tests (passed|failed)' /tmp/rt.out >&2
    sed -n '/^FAILED TEST SUMMARY/,/^=====/p' /tmp/rt.out | grep -oE '\[[^]]+\.phpt\]' | tr -d '[]' | LC_ALL=C sort -u
  " > "$RES/failed-$t.txt" 2> "$RES/summary-$t.txt"
  echo "$t: $(tr '\n' ' ' < "$RES/summary-$t.txt" | tr -s ' ')"
done
echo "-- tests failing only after the patch:"
LC_ALL=C comm -13 "$RES/failed-base.txt" "$RES/failed-fix.txt" | tee "$RES/regressions.txt"
