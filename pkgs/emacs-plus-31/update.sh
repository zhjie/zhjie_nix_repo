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

PATCHES_REPO_URL="https://github.com/d12frosted/homebrew-emacs-plus.git"
echo "Resolving current commit of homebrew-emacs-plus master branch..."
NEW_PATCHES_REV=$(git ls-remote "$PATCHES_REPO_URL" refs/heads/master | cut -f1)
if [ -z "$NEW_PATCHES_REV" ]; then
  echo "Failed to get current commit of homebrew-emacs-plus master branch" >&2
  exit 1
fi
echo "Using homebrew-emacs-plus commit: $NEW_PATCHES_REV"

# Extract existing revision from hashes.json if it exists
EXISTING_PATCHES_REV=""
if [ -f "$HASHES_FILE" ]; then
  EXISTING_URL=$(jq -r '.. | .url? // empty' "$HASHES_FILE" | grep 'homebrew-emacs-plus' | head -n1 || true)
  if [ -n "$EXISTING_URL" ]; then
    EXISTING_PATCHES_REV=$(printf '%s\n' "$EXISTING_URL" | sed -nE 's|.*/homebrew-emacs-plus/([^/]+)/.*|\1|p' | head -n1)
  fi
fi

# Helper function to get correct URL for a patch
get_patch_url() {
  local name="$1"
  local ver="$2"
  local rev="$3"
  local url
  # Community patches are under community/patches/<name>/emacs-<ver>.patch
  if [ "$name" = "mac-font-use-typo-metrics" ] || [ "$name" = "aggressive-read-buffering" ]; then
    url="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/${rev}/community/patches/${name}/emacs-${ver}.patch"
  else
    # Built-in patches are under patches/emacs-<ver>/<name>.patch
    url="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/${rev}/patches/emacs-${ver}/${name}.patch"
  fi

  # Resolve Git symlink if the target is a relative path (e.g. starting with ../)
  local content
  content=$(curl -sL --max-filesize 1000 "$url" || true)
  if [[ "$content" =~ ^\.\./ ]]; then
    # e.g., if content is ../emacs-28/fix-window-role.patch
    # strip the leading "../" and prepend the base repo patches path
    local rel_path=${content#../}
    url="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/${rev}/patches/${rel_path}"
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
  url=$(get_patch_url "$patch" "$EMACS_MAJOR_VERSION" "$NEW_PATCHES_REV")
  echo "Prefetching patch: $patch from $url..."
  set +e
  output=$(
    nix build --no-link --impure --expr \
      "let pkgs = import <nixpkgs> {}; in pkgs.fetchpatch { url = \"$url\"; hash = pkgs.lib.fakeHash; }" \
      2>&1
  )
  rc=$?
  set -e
  hash=$(printf '%s\n' "$output" | sed -n 's/.*got: *//p' | tail -n 1)
  if [ "$rc" -eq 0 ] || [ -z "$hash" ]; then
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
ICNS_URL="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/${NEW_PATCHES_REV}/community/icons/dragon-plus/icon.icns"
echo "Prefetching icon.icns..."
ICNS_HASH=$(nix store prefetch-file --json "$ICNS_URL" | jq -r '.hash')

ASSETS_URL="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/${NEW_PATCHES_REV}/community/icons/dragon-plus/Assets.car"
echo "Prefetching Assets.car..."
ASSETS_HASH=$(nix store prefetch-file --json "$ASSETS_URL" | jq -r '.hash')

# Check if all hashes match
ALL_MATCH=0
if [ -n "$EXISTING_PATCHES_REV" ]; then
  ALL_MATCH=1
  for patch in "${PATCHES[@]}"; do
    new_hash=$(printf '%s\n' "$PATCHES_JSON" | jq -r --arg patch "$patch" '.[$patch].hash')
    existing_hash=$(jq -r --arg patch "$patch" '.patches[$patch].hash // empty' "$HASHES_FILE" || true)
    if [ "$new_hash" != "$existing_hash" ]; then
      ALL_MATCH=0
      break
    fi
  done
  
  if [ "$ALL_MATCH" -eq 1 ]; then
    existing_count=$(jq '.patches | length' "$HASHES_FILE" || true)
    if [ "$existing_count" -ne "${#PATCHES[@]}" ]; then
      ALL_MATCH=0
    fi
  fi

  if [ "$ALL_MATCH" -eq 1 ]; then
    existing_icns_hash=$(jq -r '.icon.icns.hash // empty' "$HASHES_FILE" || true)
    existing_assets_hash=$(jq -r '.icon.assets.hash // empty' "$HASHES_FILE" || true)
    if [ "$existing_icns_hash" != "$ICNS_HASH" ] || [ "$existing_assets_hash" != "$ASSETS_HASH" ]; then
      ALL_MATCH=0
    fi
  fi
fi

if [ "$ALL_MATCH" -eq 1 ]; then
  echo "All hashes are unchanged. Keeping existing pin in URL: $EXISTING_PATCHES_REV"
  PATCHES_REV="$EXISTING_PATCHES_REV"
  PATCHES_JSON="${PATCHES_JSON//"$NEW_PATCHES_REV"/"$EXISTING_PATCHES_REV"}"
  ICNS_URL="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/${PATCHES_REV}/community/icons/dragon-plus/icon.icns"
  ASSETS_URL="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/${PATCHES_REV}/community/icons/dragon-plus/Assets.car"
else
  echo "Hashes have updated. Using new pin: $NEW_PATCHES_REV"
  PATCHES_REV="$NEW_PATCHES_REV"
fi

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
