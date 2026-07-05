#!/usr/bin/env bash
# Update Emacs patches and icon hashes for Nix packaging.
# Usage:
#   ./update.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"

EMACS_VERSION="30"
PATCHES=(
  "mac-font-use-typo-metrics"
  "aggressive-read-buffering"
  "fix-window-role"
  "system-appearance"
  "round-undecorated-frame"
  "fix-macos-tahoe-scrolling"
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

# Fetch patches
echo "Fetching patches hashes..."
PATCHES_JSON="{"
for i in "${!PATCHES[@]}"; do
  patch="${PATCHES[$i]}"
  url=$(get_patch_url "$patch" "$EMACS_VERSION")
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
ICNS_URL="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/community/icons/dragon-plus/icon.icns"
echo "Prefetching icon.icns..."
ICNS_HASH=$(nix store prefetch-file --json "$ICNS_URL" | jq -r '.hash')

ASSETS_URL="https://raw.githubusercontent.com/d12frosted/homebrew-emacs-plus/master/community/icons/dragon-plus/Assets.car"
echo "Prefetching Assets.car..."
ASSETS_HASH=$(nix store prefetch-file --json "$ASSETS_URL" | jq -r '.hash')

jq -n \
  --argjson patches "$PATCHES_JSON" \
  --arg icns_url "$ICNS_URL" \
  --arg icns_hash "$ICNS_HASH" \
  --arg assets_url "$ASSETS_URL" \
  --arg assets_hash "$ASSETS_HASH" \
  '{
    patches: $patches,
    icon: {
      icns: { url: $icns_url, hash: $icns_hash },
      assets: { url: $assets_url, hash: $assets_hash }
    }
  }' > "$HASHES_FILE"

echo "Updated hashes.json successfully!"
