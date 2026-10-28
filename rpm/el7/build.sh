#!/usr/bin/env bash
# Rebuild Remi's php73 source RPM (published for EL8/EL9 only) on CentOS 7, twice: with the
# PHP2Shell patches (fix) and without them (base), so verify.sh can compare like with like.
# Usage: rpm/el7/build.sh <out-dir>
#   e.g. rpm/el7/build.sh out/el7   ->  out/el7/{fix,base}/*.rpm, out/el7/fix/SHA256SUMS,
#                                       out/el7/src (prepared source tree for verify.sh)
set -euo pipefail
OUT="${1:?usage: build.sh <out-dir>}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# Remi's SRPMS directory keeps older builds. Its signature (key befa00e2, RPM-GPG-KEY-remi2026)
# was checked on Rocky 9; CentOS 7's rpm cannot read it, so the build pins the hash instead.
SRPM=php-7.3.33-24.remi.src.rpm
SUM=0ffa30c250cfbafb88cff1ec9689c002efa4cd48132872eb1482a03aeb1468df
VR=7.3.33-24.sizlon1
mkdir -p "$OUT/srpm"; OUT="$(cd "$OUT" && pwd)"

[ -f "$OUT/srpm/$SRPM" ] || curl -fsS -o "$OUT/srpm/$SRPM" "https://rpms.remirepo.net/SRPMS/$SRPM"
echo "$SUM  $OUT/srpm/$SRPM" | sha256sum -c --quiet

docker build -q -f "$REPO/rpm/el7/Dockerfile.builder" -t peb-el7-builder "$REPO" >/dev/null

docker run --rm -v "$OUT:/out" -v "$REPO/rpm/el7:/el7:ro" -e SRPM="$SRPM" -e VR="$VR" peb-el7-builder bash -euc '
  T=/root/rpmbuild; mkdir -p $T/SOURCES $T/SPECS
  # The SRPM uses rich dependencies (an EL8 rpm feature), so rpm -i fails on el7; unpack it instead.
  cd $T/SOURCES; rpm2cpio /out/srpm/$SRPM | cpio -idm --quiet
  mv php73.spec ../SPECS/
  cd ../SPECS; patch -s php73.spec < /el7/php73/php73.spec.diff
  # base: the same spec without the PHP2Shell patch (Remi Patch235)
  sed -e "s/^\(Release: [0-9]*\)\.sizlon[0-9]*/\1.base0/" -e "/^%patch -P235 /d" php73.spec > php73-base.spec
  yum -y install gd3php-devel libicu69-devel oniguruma5php-devel >/tmp/deps.log 2>&1 || { tail -30 /tmp/deps.log; exit 1; }
  yum-builddep -y php73.spec >>/tmp/deps.log 2>&1 || { tail -30 /tmp/deps.log; exit 1; }
  rpmbuild -bp php73.spec >/tmp/prep.log 2>&1 || { tail -30 /tmp/prep.log; exit 1; }
  rm -rf /out/src; cp -a $T/BUILD/php-7.3.33 /out/src
  for t in fix base; do
    spec=php73.spec; [ $t = base ] && spec=php73-base.spec
    rm -rf $T/RPMS
    rpmbuild -bb --define "runselftest 0" $spec >/tmp/build-$t.log 2>&1 || { tail -40 /tmp/build-$t.log; exit 1; }
    mkdir -p /out/$t; mv $T/RPMS/*/*.rpm /out/$t/; cp /tmp/build-$t.log /out/
    echo "$t: $(ls /out/$t/*.rpm | wc -l) packages, $(rpm -qp --qf "%{VERSION}-%{RELEASE}" /out/$t/php-cli-*.rpm)"
  done
  /el7/sha256sums.sh /out/fix "$VR"
'
