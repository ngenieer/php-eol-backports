#!/usr/bin/env bash
# Apply the unofficial PHP2Shell backport to an extracted PHP source tree.
# Usage: scripts/apply.sh <php-source-dir>
#   e.g. scripts/apply.sh /usr/local/src/php-7.3.33
set -euo pipefail

SRC="${1:?usage: apply.sh <php-source-dir>}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

VER="$(grep -E '^#define PHP_VERSION ' "$SRC/main/php_version.h" | sed -E 's/.*"([0-9]+\.[0-9]+)\..*/\1/')"
PATCH_DIR="$REPO/patches/$VER"
[ -d "$PATCH_DIR" ] || { echo "No backport for PHP $VER (have: $(ls "$REPO/patches" | tr '\n' ' '))" >&2; exit 1; }

cd "$SRC"
for p in "$PATCH_DIR"/*.patch; do
  echo "checking $(basename "$p")"
  patch -p1 --dry-run --silent < "$p" || { echo "patch does not apply cleanly; source tree may already be modified" >&2; exit 1; }
done
for p in "$PATCH_DIR"/*.patch; do
  patch -p1 --silent < "$p"
  echo "applied  $(basename "$p")"
done
echo "Done. Rebuild PHP (make && make install) and restart every PHP worker (php-fpm, Apache)."
