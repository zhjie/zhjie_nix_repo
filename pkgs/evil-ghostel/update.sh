#!/usr/bin/env bash
# Update pkgs/evil-ghostel to the latest upstream ghostel Git tag.
#
# Usage:
#   pkgs/evil-ghostel/update.sh          # auto-detect latest tag
#   pkgs/evil-ghostel/update.sh 0.41.0   # pin to a specific version tag
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
UPSTREAM="https://github.com/dakra/ghostel.git"

if [ "${1:-}" != "" ]; then
  LATEST="${1#v}"
  REV="$(git ls-remote --tags --refs "$UPSTREAM" "refs/tags/v${LATEST}" | cut -f1)"
  if [ -z "$REV" ]; then
    printf 'Error: tag v%s not found in %s\n' "$LATEST" "$UPSTREAM" >&2
    exit 1
  fi
else
  TAG_LINE="$(git ls-remote --tags --refs "$UPSTREAM" 'refs/tags/v*' \
    | sed 's#refs/tags/v##' \
    | sort -t$'\t' -k2,2V \
    | tail -n1)"
  REV="${TAG_LINE%%$'\t'*}"
  LATEST="${TAG_LINE##*$'\t'}"
fi

SYSTEM="${SYSTEM:-$(nix eval --raw --impure --expr builtins.currentSystem)}"
CURRENT="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "0.0.0")"
printf 'Current: %s  Latest: %s\n' "$CURRENT" "$LATEST"

SOURCE_URL="https://github.com/dakra/ghostel/archive/refs/tags/v${LATEST}.tar.gz"

printf 'Fetching source hash...\n'
SOURCE_HASH="$(nix store prefetch-file --unpack --json "$SOURCE_URL" | jq -r '.hash')"
printf '  sourceHash: %s\n' "$SOURCE_HASH"

jq -n \
  --arg version "$LATEST" \
  --arg rev "$REV" \
  --arg sourceHash "$SOURCE_HASH" \
  '{ version: $version, rev: $rev, sourceHash: $sourceHash }' \
  > "$HASHES_FILE"

printf 'Verifying updated evil-ghostel package build...\n'
nix build "path:$REPO_ROOT#packages.${SYSTEM}.evil-ghostel" --no-link
printf 'Updated evil-ghostel to %s\n' "$LATEST"
