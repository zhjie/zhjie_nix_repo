#!/usr/bin/env bash
# Update pkgs/pi-coding-agent to the latest upstream Git tag.
#
# Usage:
#   pkgs/pi-coding-agent/update.sh          # auto-detect latest version
#   pkgs/pi-coding-agent/update.sh 0.80.3   # pin to a specific version
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
UPSTREAM="https://github.com/earendil-works/pi.git"

if [ "${1:-}" != "" ]; then
  LATEST="${1#v}"
else
  # Retrieve the latest tag matching vX.Y.Z
  TAG_LINE="$(git ls-remote --tags --refs "$UPSTREAM" 'refs/tags/v*' \
    | sed -nE 's#.*refs/tags/v([0-9]+\.[0-9]+\.[0-9]+)$#\1#p' \
    | sort -V \
    | tail -n1)"
  LATEST="$TAG_LINE"
fi

SYSTEM="${SYSTEM:-$(nix eval --raw --impure --expr builtins.currentSystem)}"
CURRENT="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "0.0.0")"
printf 'Current: %s  Latest: %s\n' "$CURRENT" "$LATEST"

if [ "$CURRENT" = "$LATEST" ] && jq -e '.sourceHash' "$HASHES_FILE" >/dev/null 2>&1 && jq -e '.npmDepsHash' "$HASHES_FILE" >/dev/null 2>&1; then
  printf 'Already up to date.\n'
  exit 0
fi

SOURCE_URL="https://github.com/earendil-works/pi/archive/refs/tags/v${LATEST}.tar.gz"

printf 'Fetching source hash...\n'
SOURCE_HASH="$(nix store prefetch-file --unpack --json "$SOURCE_URL" | jq -r '.hash')"
printf '  sourceHash: %s\n' "$SOURCE_HASH"

printf 'Computing npmDepsHash...\n'
TMP_HASHES="$(mktemp)"
cp "$HASHES_FILE" "$TMP_HASHES" 2>/dev/null || true
trap 'cp "$TMP_HASHES" "$HASHES_FILE" 2>/dev/null || true; rm -f "$TMP_HASHES"' ERR

jq -n \
  --arg version "$LATEST" \
  --arg sourceHash "$SOURCE_HASH" \
  --arg npmDepsHash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" \
  '{ version: $version, sourceHash: $sourceHash, npmDepsHash: $npmDepsHash }' \
  > "$HASHES_FILE"

set +e
BUILD_OUTPUT="$(nix build "$REPO_ROOT#packages.${SYSTEM}.pi-coding-agent.npmDeps" --no-link 2>&1)"
BUILD_STATUS=$?
set -e

NPM_DEPS_HASH="$(printf '%s\n' "$BUILD_OUTPUT" \
  | sed -nE 's/.*got:[[:space:]]+(sha256-[A-Za-z0-9+/=]+).*/\1/p' \
  | tail -n1)"

if [ "$BUILD_STATUS" -eq 0 ] || [ -z "$NPM_DEPS_HASH" ]; then
  printf '%s\n' "$BUILD_OUTPUT" >&2
  printf 'Error: could not extract npmDepsHash from nix build output.\n' >&2
  exit 1
fi

trap - ERR
rm -f "$TMP_HASHES"
printf '  npmDepsHash: %s\n' "$NPM_DEPS_HASH"

jq -n \
  --arg version "$LATEST" \
  --arg sourceHash "$SOURCE_HASH" \
  --arg npmDepsHash "$NPM_DEPS_HASH" \
  '{ version: $version, sourceHash: $sourceHash, npmDepsHash: $npmDepsHash }' \
  > "$HASHES_FILE"

printf 'Verifying updated pi-coding-agent package build...\n'
nix build "$REPO_ROOT#packages.${SYSTEM}.pi-coding-agent" --no-link
printf 'Updated pi-coding-agent to %s\n' "$LATEST"
