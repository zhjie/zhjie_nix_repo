#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
OWNER="dgillis"
REPO="emacs-codex-ide"
REMOTE="https://github.com/${OWNER}/${REPO}.git"

if [ "${1:-}" != "" ]; then
  REV="$1"
else
  REV="$(git ls-remote "$REMOTE" HEAD | cut -f1)"
fi

COMMIT_DATE="$(gh api "repos/${OWNER}/${REPO}/commits/${REV}" --jq '.commit.committer.date[0:10]')"
PACKAGE_EL="$(gh api "repos/${OWNER}/${REPO}/contents/codex-ide.el?ref=${REV}" --jq '.content' | base64 --decode)"
UPSTREAM_VERSION="$(printf '%s\n' "$PACKAGE_EL" | sed -nE 's/^;; Version:[[:space:]]*([^[:space:]]+).*/\1/p' | head -n1)"

if [ -z "$UPSTREAM_VERSION" ]; then
  printf 'Error: could not parse Version header from codex-ide.el\n' >&2
  exit 1
fi

VERSION="${UPSTREAM_VERSION}-unstable-${COMMIT_DATE}"
CURRENT_REV="$(jq -r '.rev' "$HASHES_FILE" 2>/dev/null || echo "")"
CURRENT_VERSION="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "")"
printf 'Current: %s (%s)  Latest: %s (%s)\n' "$CURRENT_VERSION" "$CURRENT_REV" "$VERSION" "$REV"

if [ "$CURRENT_REV" = "$REV" ] && jq -e '(.version | length > 0) and (.sourceHash | length > 0)' "$HASHES_FILE" >/dev/null 2>&1; then
  printf 'Already up to date.\n'
  exit 0
fi

SOURCE_URL="https://github.com/${OWNER}/${REPO}/archive/${REV}.tar.gz"

printf 'Fetching source hash...\n'
SOURCE_HASH="$(nix store prefetch-file --unpack --json "$SOURCE_URL" | jq -r '.hash')"
printf '  sourceHash: %s\n' "$SOURCE_HASH"

jq -n \
  --arg version "$VERSION" \
  --arg rev "$REV" \
  --arg sourceHash "$SOURCE_HASH" \
  '{ version: $version, rev: $rev, sourceHash: $sourceHash }' \
  > "$HASHES_FILE"

printf 'Updated codex-ide to %s (%s)\n' "$VERSION" "$REV"
