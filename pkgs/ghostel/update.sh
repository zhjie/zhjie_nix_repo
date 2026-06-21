#!/usr/bin/env bash
# Update pkgs/ghostel to the latest upstream Git tag.
#
# Usage:
#   pkgs/ghostel/update.sh          # auto-detect latest tag
#   pkgs/ghostel/update.sh 0.36.0   # pin to a specific version tag
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

CURRENT="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "0.0.0")"
printf 'Current: %s  Latest: %s\n' "$CURRENT" "$LATEST"

if [ "$CURRENT" = "$LATEST" ] \
  && jq -e '.rev and .sourceHash and .zigDepsHash' "$HASHES_FILE" >/dev/null 2>&1; then
  printf 'Already up to date.\n'
  exit 0
fi

SOURCE_URL="https://github.com/dakra/ghostel/archive/refs/tags/v${LATEST}.tar.gz"

printf 'Fetching source hash...\n'
SOURCE_HASH="$(nix store prefetch-file --unpack --json "$SOURCE_URL" | jq -r '.hash')"
printf '  sourceHash: %s\n' "$SOURCE_HASH"

printf 'Computing zigDepsHash...\n'
TMP_HASHES="$(mktemp)"
cp "$HASHES_FILE" "$TMP_HASHES" 2>/dev/null || true
trap 'cp "$TMP_HASHES" "$HASHES_FILE" 2>/dev/null || true; rm -f "$TMP_HASHES"' ERR

jq -n \
  --arg version "$LATEST" \
  --arg rev "$REV" \
  --arg sourceHash "$SOURCE_HASH" \
  --arg zigDepsHash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" \
  '{ version: $version, rev: $rev, sourceHash: $sourceHash, zigDepsHash: $zigDepsHash }' \
  > "$HASHES_FILE"

SYSTEM="${SYSTEM:-$(nix eval --raw --impure --expr builtins.currentSystem)}"
set +e
BUILD_OUTPUT="$(nix build "$REPO_ROOT#packages.${SYSTEM}.ghostel.module" --no-link 2>&1)"
BUILD_STATUS=$?
set -e

ZIG_DEPS_HASH="$(printf '%s\n' "$BUILD_OUTPUT" \
  | sed -nE 's/.*got:[[:space:]]+(sha256-[A-Za-z0-9+/=]+).*/\1/p' \
  | tail -n1)"

if [ "$BUILD_STATUS" -eq 0 ] || [ -z "$ZIG_DEPS_HASH" ]; then
  printf '%s\n' "$BUILD_OUTPUT" >&2
  printf 'Error: could not extract zigDepsHash from nix build output.\n' >&2
  exit 1
fi

trap - ERR
rm -f "$TMP_HASHES"
printf '  zigDepsHash: %s\n' "$ZIG_DEPS_HASH"

jq -n \
  --arg version "$LATEST" \
  --arg rev "$REV" \
  --arg sourceHash "$SOURCE_HASH" \
  --arg zigDepsHash "$ZIG_DEPS_HASH" \
  '{ version: $version, rev: $rev, sourceHash: $sourceHash, zigDepsHash: $zigDepsHash }' \
  > "$HASHES_FILE"

printf 'Updated ghostel to %s\n' "$LATEST"
