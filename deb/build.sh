#!/usr/bin/env bash
# Rebuild Sury's current php<x.y> Debian source (which already carries the PHP2Shell fix) for an
# EOL distro whose Sury repository is gone, twice: as released (fix) and without the bailout
# patch (base), so verify.sh can compare like with like.
# Usage: deb/build.sh <buster|bionic> <x.y> <out-dir>
#   e.g. deb/build.sh buster 7.3 out/buster-7.3   ->  out/buster-7.3/{fix,base}/*.deb, out/buster-7.3/fix/SHA256SUMS
set -euo pipefail
DIST="${1:?usage: build.sh <buster|bionic> <x.y> <out-dir>}"; VER="${2:?}"; OUT="${3:?}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
case "$DIST" in
  buster) BASE=debian:buster; DV=debian10 ;;
  bionic) BASE=ubuntu:18.04;  DV=ubuntu18.04 ;;
  *) echo "unknown dist $DIST" >&2; exit 1 ;;
esac
mkdir -p "$OUT/src"; OUT="$(cd "$OUT" && pwd)"

SRCV=""
while read -r pkg ver file sum; do
  [ "$pkg" = "php$VER" ] || continue
  SRCV="$ver"
  [ -f "$OUT/src/$file" ] || curl -fsS -o "$OUT/src/$file" "https://packages.sury.org/php/pool/main/p/$pkg/${file//+/%2B}"
  echo "$sum  $OUT/src/$file" | sha256sum -c --quiet
done < <(grep -v '^#' "$REPO/deb/sources.txt")
[ -n "$SRCV" ] || { echo "php$VER not in deb/sources.txt" >&2; exit 1; }
NEWV="${SRCV/debian12/$DV}"

docker build -q -f "$REPO/deb/Dockerfile" --build-arg BASE="$BASE" --target builder -t "peb-deb-builder:$DIST" "$REPO" >/dev/null

docker run --rm -v "$OUT:/out" -e VER="$VER" -e DIST="$DIST" -e NEWV="$NEWV" "peb-deb-builder:$DIST" bash -euc '
  cd /tmp
  tar xf /out/src/php${VER}_*.orig.tar.xz; mv php-* tree; tar xf /out/src/*.debian.tar.xz -C tree
  cd tree
  apt-get -o Acquire::Check-Valid-Until=false update >/dev/null
  mk-build-deps -ir -t "apt-get -y --no-install-recommends" debian/control >/tmp/deps.log 2>&1 || { tail -30 /tmp/deps.log; exit 1; }
  for t in fix base; do
    rm -rf /tmp/$t; cp -a /tmp/tree /tmp/$t; cd /tmp/$t
    if [ $t = fix ]; then v="$NEWV+sizlon1"; msg="Rebuild of Sury php$VER for $DIST (its Sury repository is gone); carries the PHP2Shell fix (CVE-2026-109618, CVE-2026-109619)."
    else v="$NEWV+base0"; msg="Test build only: Sury php$VER without the PHP2Shell patch, for comparison."
      sed -i "/Avoid-state-corruption-via-bailout/d" debian/patches/series; fi
    { printf "php%s (%s) %s; urgency=high\n\n  * %s\n    https://github.com/ngenieer/php-eol-backports\n\n -- sizlon <admin@sizlon.io>  %s\n\n" \
        "$VER" "$v" "$DIST" "$msg" "$(date -R)"; cat debian/changelog; } > debian/changelog.new
    mv debian/changelog.new debian/changelog
    DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -us -uc -b >/tmp/build-$t.log 2>&1 || { tail -40 /tmp/build-$t.log; exit 1; }
    mkdir -p /out/$t; mv /tmp/*.deb /out/$t/; cp /tmp/build-$t.log /out/
    echo "$t: $(ls /out/$t/*.deb | wc -l) packages, $v"
  done
  # SHA256SUMS for the release, covering only this build. GitHub stores asset names with "~"
  # replaced by ".", so list the names a download will have.
  cd /out/fix
  sha256sum $(ls *.deb | grep -F "$NEWV+sizlon1") | sed "s/~/./g" > SHA256SUMS
  echo "fix: SHA256SUMS, $(wc -l < SHA256SUMS) files"
'
