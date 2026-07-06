#!/usr/bin/env bash
# Update Emacs source, patch, and icon hashes for Nix packaging.
# Usage:
#   ./update.sh              # refresh the rev currently recorded in hashes.json
#   ./update.sh <commit-sha> # refresh and pin to a specific Emacs commit
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

EMACS_MAJOR_VERSION="31"
EMACS_BASE_VERSION="31.0.90"
EMACS_REPO_URL="https://github.com/emacs-mirror/emacs.git"
EMACS_BRANCH="emacs-31"
DEFAULT_EMACS_REV="$(jq -r '.rev // empty' "$HASHES_FILE" 2>/dev/null || true)"
EMACS_REV="${1:-$DEFAULT_EMACS_REV}"

if [ -z "$EMACS_REV" ]; then
  echo "Usage: $0 <commit-sha>" >&2
  echo "No Emacs rev argument was provided and hashes.json does not contain .rev" >&2
  exit 1
fi

PATCHES=(
  "mac-font-use-typo-metrics"
  "aggressive-read-buffering"
  "system-appearance"
  "round-undecorated-frame"
  "fix-ns-x-colors"
)

# Helper function to get correct URL for a patch
get_patch_url() {
  local name="$1"
  local ver="$2"
  local url
  # Community patches are under community/patches/<name>/emacs-<ver>.patch
  if [ "$name" = "mac-font-use-typo-metrics" ] || [ "$name" = "aggressive-read-buffering" ]; then
    url="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/community/patches/${name}/emacs-${ver}.patch"
  else
    # Built-in patches are under patches/emacs-<ver>/<name>.patch
    url="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/emacs-${ver}/${name}.patch"
  fi

  # Resolve Git symlink if the target is a relative path (e.g. starting with ../)
  local content
  content=$(curl -sL --max-filesize 1000 "$url" || true)
  if [[ "$content" =~ ^\.\./ ]]; then
    # e.g., if content is ../emacs-28/fix-window-role.patch
    # strip the leading "../" and prepend the base repo patches path
    local rel_path=${content#../}
    url="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/patches/${rel_path}"
  fi
  echo "$url"
}

# Fetch Emacs source metadata
echo "Fetching Emacs source metadata for $EMACS_REV..."
if [ "${#EMACS_REV}" -lt 40 ]; then
  LS_REMOTE_OUTPUT=$(git ls-remote "$EMACS_REPO_URL")
  RESOLVED_REV=$(printf '%s\n' "$LS_REMOTE_OUTPUT" | awk -v rev="$EMACS_REV" 'index($1, rev) == 1 { print $1; exit }')
  if [ -z "$RESOLVED_REV" ]; then
    echo "Failed to resolve short Emacs rev $EMACS_REV" >&2
    exit 1
  fi
  EMACS_REV="$RESOLVED_REV"
fi

git_tmpdir=$(mktemp -d)
trap 'rm -rf "$git_tmpdir"' EXIT
git -C "$git_tmpdir" init -q
git -C "$git_tmpdir" fetch --depth=1 "$EMACS_REPO_URL" "$EMACS_REV"
COMMIT_DATE=$(git -C "$git_tmpdir" show -s --format=%cs FETCH_HEAD)
if [ -z "$COMMIT_DATE" ]; then
  echo "Failed to resolve commit date for Emacs rev $EMACS_REV" >&2
  exit 1
fi
EMACS_PACKAGE_VERSION="${EMACS_BASE_VERSION}-unstable-${COMMIT_DATE}"

set +e
output=$(
  nix build --no-link --impure --expr \
    "let pkgs = import <nixpkgs> {}; in pkgs.fetchgit { url = \"$EMACS_REPO_URL\"; rev = \"$EMACS_REV\"; branchName = \"$EMACS_BRANCH\"; hash = pkgs.lib.fakeHash; }" \
    2>&1
)
status=$?
set -e
SOURCE_HASH=$(printf '%s\n' "$output" | sed -n 's/.*got: *//p' | tail -n 1)
if [ "$status" -eq 0 ] || [ -z "$SOURCE_HASH" ]; then
  printf '%s\n' "$output" >&2
  echo "Failed to prefetch Emacs source hash for $EMACS_REV" >&2
  exit 1
fi

# Fetch patches
echo "Fetching patches hashes..."
PATCHES_JSON="{"
for i in "${!PATCHES[@]}"; do
  patch="${PATCHES[$i]}"
  url=$(get_patch_url "$patch" "$EMACS_MAJOR_VERSION")
  echo "Prefetching patch: $patch from $url..."
  set +e
  output=$(
    nix build --no-link --impure --expr \
      "let pkgs = import <nixpkgs> {}; in pkgs.fetchpatch { url = \"$url\"; hash = pkgs.lib.fakeHash; }" \
      2>&1
  )
  status=$?
  set -e
  hash=$(printf '%s\n' "$output" | sed -n 's/.*got: *//p' | tail -n 1)
  if [ "$status" -eq 0 ] || [ -z "$hash" ]; then
    printf '%s\n' "$output" >&2
    echo "Failed to prefetch normalized fetchpatch hash for $patch" >&2
    exit 1
  fi
  
  if [ $i -ne 0 ]; then
    PATCHES_JSON+=$',\n'
  fi
  PATCHES_JSON+="  \"$patch\": { \"url\": \"$url\", \"hash\": \"$hash\" }"
done
PATCHES_JSON+="}"

# Fetch icon
echo "Fetching icon hashes..."
ICNS_URL="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/community/icons/dragon-plus/icon.icns"
echo "Prefetching icon.icns..."
ICNS_HASH=$(nix store prefetch-file --json "$ICNS_URL" | jq -r '.hash')

ASSETS_URL="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/community/icons/dragon-plus/Assets.car"
echo "Prefetching Assets.car..."
ASSETS_HASH=$(nix store prefetch-file --json "$ASSETS_URL" | jq -r '.hash')

jq -n \
  --arg version "$EMACS_PACKAGE_VERSION" \
  --arg rev "$EMACS_REV" \
  --arg source_hash "$SOURCE_HASH" \
  --argjson patches "$PATCHES_JSON" \
  --arg icns_url "$ICNS_URL" \
  --arg icns_hash "$ICNS_HASH" \
  --arg assets_url "$ASSETS_URL" \
  --arg assets_hash "$ASSETS_HASH" \
  '{
    version: $version,
    rev: $rev,
    sourceHash: $source_hash,
    patches: $patches,
    icon: {
      icns: { url: $icns_url, hash: $icns_hash },
      assets: { url: $assets_url, hash: $assets_hash }
    }
  }' > "$HASHES_FILE"

echo "Updated hashes.json successfully!"
