#!/usr/bin/env bash
# Update pkgs/roonserver to the latest version.
#
# Usage:
#   pkgs/roonserver/update.sh          # auto-detect latest version
#   pkgs/roonserver/update.sh 2.67.1661 # pin to a specific version
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

# ── Resolve Version ───────────────────────────────────────────────────────────
if [ "${1:-}" != "" ]; then
  LATEST="$1"
else
  # Fetch latest update URL and displayversion from Roon Labs API
  API_URL="https://updates.roonlabs.net/update/?v=2&platform=linux&version=&product=RoonServer&branding=roon&branch=production&curbranch=production"
  RESPONSE="$(curl -fsSL "$API_URL")"
  
  if [[ "$RESPONSE" =~ displayversion=([^\r\n]+) ]]; then
    DISPLAY_VERSION="${BASH_REMATCH[1]}"
  else
    DISPLAY_VERSION=""
  fi
  
  if [[ "$DISPLAY_VERSION" =~ ([0-9]+\.[0-9]+)[[:space:]]+\(build[[:space:]]+([0-9]+)\) ]]; then
    LATEST="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
  else
    printf 'Error: Could not parse version from displayversion: %s\n' "$DISPLAY_VERSION" >&2
    exit 1
  fi
fi

CURRENT="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "0.0.0")"
printf 'Current: %s  Latest: %s\n' "$CURRENT" "$LATEST"

if [ "$CURRENT" = "$LATEST" ] && jq -e '.sourceHash' "$HASHES_FILE" >/dev/null 2>&1; then
  printf 'Already up to date.\n'
  exit 0
fi

# ── Prefetch source hash ──────────────────────────────────────────────────────
# Format URL version (e.g. 2.67.1661 -> 206701661)
URL_VERSION="${LATEST//./0}"
TARBALL_URL="https://download.roonlabs.com/updates/production/RoonServer_linuxx64_${URL_VERSION}.tar.bz2"

printf 'Fetching source hash for %s...\n' "$TARBALL_URL"
SOURCE_HASH="$(nix store prefetch-file --json "$TARBALL_URL" | jq -r '.hash')"
printf '  sourceHash: %s\n' "$SOURCE_HASH"

# ── Write hashes.json ─────────────────────────────────────────────────────────
jq -n \
  --arg version    "$LATEST" \
  --arg sourceHash "$SOURCE_HASH" \
  '{ version: $version, sourceHash: $sourceHash }' \
  > "$HASHES_FILE"

printf 'Updated roon-server to %s\n' "$LATEST"
