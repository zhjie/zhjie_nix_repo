#!/usr/bin/env bash
# Update pkgs/qterm to the latest upstream Git tag.
#
# Usage:
#   pkgs/qterm/update.sh        # auto-detect latest version
#   pkgs/qterm/update.sh 0.8.2  # pin to a specific version
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
UPSTREAM="https://github.com/qterm/qterm.git"

if [ "${1:-}" != "" ]; then
  LATEST="$1"
else
  LATEST="$(git ls-remote --tags --refs "$UPSTREAM" \
    | sed -nE 's#.*refs/tags/([0-9][0-9.]+)$#\1#p' \
    | sort -V \
    | tail -n1)"
fi

CURRENT="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "0.0.0")"
printf 'Current: %s  Latest: %s\n' "$CURRENT" "$LATEST"

if [ "$CURRENT" = "$LATEST" ] && jq -e '.sourceHash' "$HASHES_FILE" >/dev/null 2>&1; then
  printf 'Already up to date.\n'
  exit 0
fi

SOURCE_URL="https://github.com/qterm/qterm/archive/refs/tags/${LATEST}.tar.gz"

printf 'Fetching source hash...\n'
SOURCE_HASH="$(nix store prefetch-file --json "$SOURCE_URL" | jq -r '.hash')"
printf '  sourceHash: %s\n' "$SOURCE_HASH"

jq -n \
  --arg version "$LATEST" \
  --arg sourceHash "$SOURCE_HASH" \
  '{ version: $version, sourceHash: $sourceHash }' \
  > "$HASHES_FILE"

printf 'Updated qterm to %s\n' "$LATEST"
