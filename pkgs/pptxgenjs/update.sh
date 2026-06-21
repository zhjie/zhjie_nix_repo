#!/usr/bin/env bash
# Update pkgs/pptxgenjs to the latest version published on npm.
#
# Usage:
#   scripts/update-pptxgenjs          # auto-detect latest version
#   scripts/update-pptxgenjs 4.0.1    # pin to a specific version
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
PKG_DIR="$SCRIPT_DIR"
HASHES_FILE="$PKG_DIR/hashes.json"
LOCKFILE="$PKG_DIR/package-lock.json"

NPM_PACKAGE="pptxgenjs"

# ── Resolve version ───────────────────────────────────────────────────────────
if [ "${1:-}" != "" ]; then
  LATEST="$1"
else
  LATEST="$(curl -fsSL "https://registry.npmjs.org/${NPM_PACKAGE}/latest" | jq -r '.version')"
fi

CURRENT="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "0.0.0")"
printf 'Current: %s  Latest: %s\n' "$CURRENT" "$LATEST"

if [ "$CURRENT" = "$LATEST" ] && [ -f "$HASHES_FILE" ] && [ -f "$LOCKFILE" ]; then
  printf 'Already up to date.\n'
  exit 0
fi

TARBALL_URL="https://registry.npmjs.org/${NPM_PACKAGE}/-/${NPM_PACKAGE}-${LATEST}.tgz"

# ── Source hash ───────────────────────────────────────────────────────────────
printf 'Fetching source hash...\n'
SOURCE_HASH="$(nix store prefetch-file --json "$TARBALL_URL" | jq -r '.hash')"
printf '  sourceHash: %s\n' "$SOURCE_HASH"

# ── Regenerate package-lock.json ──────────────────────────────────────────────
printf 'Regenerating package-lock.json...\n'
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Extract package.json from the tarball
curl -fsSL "$TARBALL_URL" | tar -xzf - -C "$TMPDIR" --strip-components=1 package/package.json

# Strip devDependencies to keep package-lock.json minimal and build super fast
jq 'del(.devDependencies)' "$TMPDIR/package.json" > "$TMPDIR/package.json.tmp"
mv "$TMPDIR/package.json.tmp" "$TMPDIR/package.json"

# Generate a fresh package-lock.json (deps only, no install)
(cd "$TMPDIR" && npm install --package-lock-only --ignore-scripts --loglevel=error)
cp "$TMPDIR/package-lock.json" "$LOCKFILE"
printf '  package-lock.json updated\n'

# ── npmDepsHash ───────────────────────────────────────────────────────────────
printf 'Computing npmDepsHash...\n'
NPM_DEPS_HASH="$(nix run nixpkgs#prefetch-npm-deps -- "$LOCKFILE" 2>/dev/null)"
printf '  npmDepsHash: %s\n' "$NPM_DEPS_HASH"

# ── Write hashes.json ─────────────────────────────────────────────────────────
jq -n \
  --arg version    "$LATEST" \
  --arg sourceHash "$SOURCE_HASH" \
  --arg npmDepsHash "$NPM_DEPS_HASH" \
  '{ version: $version, sourceHash: $sourceHash, npmDepsHash: $npmDepsHash }' \
  > "$HASHES_FILE"

printf 'Updated %s to %s\n' "$NPM_PACKAGE" "$LATEST"
