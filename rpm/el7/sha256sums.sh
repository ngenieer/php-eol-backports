#!/usr/bin/env bash
# Write SHA256SUMS for a release of rebuilt RPMs, covering only the given version-release so
# stale RPMs from other builds in the same directory are left out. GitHub stores asset names
# with "~" replaced by ".", so list the names a download will have.
# Usage: rpm/el7/sha256sums.sh <rpm-dir> <version-release>
#   e.g. rpm/el7/sha256sums.sh out/fix 7.3.33-23.sizlon1   ->  out/fix/SHA256SUMS
set -euo pipefail
DIR="${1:?usage: sha256sums.sh <rpm-dir> <version-release>}"; VR="${2:?}"
cd "$DIR"
shopt -s nullglob
files=(*-"$VR".el7.*.rpm)
[ ${#files[@]} -gt 0 ] || { echo "no *-$VR.el7.*.rpm in $DIR" >&2; exit 1; }
sha256sum "${files[@]}" | sed "s/~/./g" > SHA256SUMS
echo "SHA256SUMS: ${#files[@]} files"
