#!/usr/bin/env bash
# Update pkgs/lean-lsp-mcp to the latest upstream Git tag.
#
# Usage:
#   pkgs/lean-lsp-mcp/update.sh          # auto-detect latest tag
#   pkgs/lean-lsp-mcp/update.sh 0.28.0   # pin to a specific version tag
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
UPSTREAM="https://github.com/oOo0oOo/lean-lsp-mcp.git"

if [ "${1:-}" != "" ]; then
  VERSION="${1#v}"
  if [ -z "$(git ls-remote --tags --refs "$UPSTREAM" "refs/tags/v${VERSION}")" ]; then
    printf 'Error: tag v%s not found in %s\n' "$VERSION" "$UPSTREAM" >&2
    exit 1
  fi
else
  VERSION="$(git ls-remote --tags --refs "$UPSTREAM" 'refs/tags/v*' \
    | sed -nE 's#.*refs/tags/v([0-9].*)#\1#p' \
    | sort -V \
    | tail -n1)"
fi

if [ -z "$VERSION" ]; then
  printf 'Error: no version tags found in %s\n' "$UPSTREAM" >&2
  exit 1
fi

CURRENT="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "0.0.0")"
printf 'Current: %s  Latest: %s\n' "$CURRENT" "$VERSION"

SOURCE_URL="https://github.com/oOo0oOo/lean-lsp-mcp/archive/refs/tags/v${VERSION}.tar.gz"

printf 'Fetching source hash...\n'
SOURCE_HASH="$(nix store prefetch-file --unpack --json "$SOURCE_URL" | jq -r '.hash')"
printf '  sourceHash: %s\n' "$SOURCE_HASH"

if [ "$CURRENT" = "$VERSION" ] && jq -e --arg sourceHash "$SOURCE_HASH" '.sourceHash == $sourceHash' "$HASHES_FILE" >/dev/null; then
  printf 'Already up to date.\n'
  exit 0
fi

jq -n \
  --arg version "$VERSION" \
  --arg sourceHash "$SOURCE_HASH" \
  '{ version: $version, sourceHash: $sourceHash }' \
  > "$HASHES_FILE"

printf 'Updated lean-lsp-mcp to %s\n' "$VERSION"
