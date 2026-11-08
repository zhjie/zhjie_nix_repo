#!/usr/bin/env bash
# Update pkgs/gpu-unlock-ada to the latest upstream Git tag.
#
# Usage:
#   pkgs/gpu-unlock-ada/update.sh          # auto-detect latest tag
#   pkgs/gpu-unlock-ada/update.sh 1.1.1    # pin to a specific version tag
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
UPSTREAM="https://github.com/JustAResearcher/gpu-unlock-ada.git"

if [ "${1:-}" != "" ]; then
  VERSION="${1#v}"
  if [ -z "$(git ls-remote --tags --refs "$UPSTREAM" "refs/tags/v${VERSION}")" ] && \
     [ -z "$(git ls-remote --tags --refs "$UPSTREAM" "refs/tags/${VERSION}")" ]; then
    printf 'Error: tag v%s or %s not found in %s\n' "$VERSION" "$VERSION" "$UPSTREAM" >&2
    exit 1
  fi
  if [ -n "$(git ls-remote --tags --refs "$UPSTREAM" "refs/tags/v${VERSION}")" ]; then
    TAG="v${VERSION}"
  else
    TAG="${VERSION}"
  fi
else
  TAG="$(git ls-remote --tags --refs "$UPSTREAM" 'refs/tags/v*' \
    | sed -nE 's#.*refs/tags/(v[0-9].*)#\1#p' \
    | sort -V \
    | tail -n1)"
  VERSION="${TAG#v}"
fi

if [ -z "$VERSION" ]; then
  printf 'Error: no version tags found in %s\n' "$UPSTREAM" >&2
  exit 1
fi

CURRENT="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "0.0.0")"
printf 'Current: %s  Latest: %s\n' "$CURRENT" "$VERSION"

SOURCE_URL="https://github.com/JustAResearcher/gpu-unlock-ada/archive/refs/tags/${TAG}.tar.gz"

printf 'Fetching source hash...\n'
PREFETCH_JSON="$(nix store prefetch-file --unpack --json "$SOURCE_URL")"
SOURCE_HASH="$(printf '%s\n' "$PREFETCH_JSON" | jq -r '.hash')"
STORE_PATH="$(printf '%s\n' "$PREFETCH_JSON" | jq -r '.storePath')"
printf '  sourceHash: %s\n' "$SOURCE_HASH"

ARTIFACTS_FILE="$(find "$STORE_PATH/firmware" -name 'artifacts-*.json' 2>/dev/null | head -n1)"
if [ -z "$ARTIFACTS_FILE" ] || [ ! -f "$ARTIFACTS_FILE" ]; then
  printf 'Error: artifacts-*.json not found in %s/firmware\n' "$STORE_PATH" >&2
  exit 1
fi

FIRMWARE_VERSION="$(basename "$ARTIFACTS_FILE" | sed -E 's/^artifacts-(.*)\.json$/\1/')"
printf '  firmwareVersion: %s\n' "$FIRMWARE_VERSION"

NVIDIA_SOURCE_URL="$(jq -r '.source_artifacts[] | select((.filename // "") | endswith(".tar.xz")) | .url' "$ARTIFACTS_FILE")"
NVIDIA_SOURCE_FILENAME="$(jq -r '.source_artifacts[] | select((.filename // "") | endswith(".tar.xz")) | .filename' "$ARTIFACTS_FILE")"
NVIDIA_SOURCE_HEX="$(jq -r '.source_artifacts[] | select((.filename // "") | endswith(".tar.xz")) | .sha256' "$ARTIFACTS_FILE")"

NVIDIA_UTILS_URL="$(jq -r '.source_artifacts[] | select((.filename // "") | endswith(".pkg.tar.zst")) | .url' "$ARTIFACTS_FILE")"
NVIDIA_UTILS_FILENAME="$(jq -r '.source_artifacts[] | select((.filename // "") | endswith(".pkg.tar.zst")) | .filename' "$ARTIFACTS_FILE")"
NVIDIA_UTILS_HEX="$(jq -r '.source_artifacts[] | select((.filename // "") | endswith(".pkg.tar.zst")) | .sha256' "$ARTIFACTS_FILE")"

NVIDIA_SOURCE_HASH="$(nix hash convert --to sri --hash-algo sha256 "$NVIDIA_SOURCE_HEX")"

# Check if upstream nvidia-utils URL is alive; if 404, fallback to Arch Linux official archive
if ! curl -fsSL -I "$NVIDIA_UTILS_URL" >/dev/null 2>&1; then
  ARCH_URL="https://archive.archlinux.org/packages/n/nvidia-utils/nvidia-utils-${FIRMWARE_VERSION}-1-x86_64.pkg.tar.zst"
  if curl -fsSL -I "$ARCH_URL" >/dev/null 2>&1; then
    printf '  Notice: upstream nvidia-utils URL unavailable, using Arch archive: %s\n' "$ARCH_URL"
    NVIDIA_UTILS_URL="$ARCH_URL"
    NVIDIA_UTILS_FILENAME="nvidia-utils-${FIRMWARE_VERSION}-1-x86_64.pkg.tar.zst"
    PREFETCH_UTILS="$(nix store prefetch-file --json "$NVIDIA_UTILS_URL")"
    NVIDIA_UTILS_HASH="$(printf '%s\n' "$PREFETCH_UTILS" | jq -r '.hash')"
    NVIDIA_UTILS_HEX="$(nix hash convert --to base16 --hash-algo sha256 "$NVIDIA_UTILS_HASH")"
  else
    NVIDIA_UTILS_HASH="$(nix hash convert --to sri --hash-algo sha256 "$NVIDIA_UTILS_HEX")"
  fi
else
  NVIDIA_UTILS_HASH="$(nix hash convert --to sri --hash-algo sha256 "$NVIDIA_UTILS_HEX")"
fi

if [ "$CURRENT" = "$VERSION" ] && \
   jq -e --arg sourceHash "$SOURCE_HASH" '.sourceHash == $sourceHash' "$HASHES_FILE" >/dev/null 2>&1 && \
   jq -e --arg utilsHash "$NVIDIA_UTILS_HASH" '.nvidiaUtilsHash == $utilsHash' "$HASHES_FILE" >/dev/null 2>&1 && \
   jq -e --arg fwVersion "$FIRMWARE_VERSION" '.firmwareVersion == $fwVersion' "$HASHES_FILE" >/dev/null 2>&1; then
  printf 'Already up to date.\n'
  exit 0
fi

jq -n \
  --arg version "$VERSION" \
  --arg sourceHash "$SOURCE_HASH" \
  --arg firmwareVersion "$FIRMWARE_VERSION" \
  --arg nvidiaSourceUrl "$NVIDIA_SOURCE_URL" \
  --arg nvidiaSourceFilename "$NVIDIA_SOURCE_FILENAME" \
  --arg nvidiaSourceHash "$NVIDIA_SOURCE_HASH" \
  --arg nvidiaUtilsUrl "$NVIDIA_UTILS_URL" \
  --arg nvidiaUtilsFilename "$NVIDIA_UTILS_FILENAME" \
  --arg nvidiaUtilsSha256 "$NVIDIA_UTILS_HEX" \
  --arg nvidiaUtilsHash "$NVIDIA_UTILS_HASH" \
  '{
    version: $version,
    sourceHash: $sourceHash,
    firmwareVersion: $firmwareVersion,
    nvidiaSourceUrl: $nvidiaSourceUrl,
    nvidiaSourceFilename: $nvidiaSourceFilename,
    nvidiaSourceHash: $nvidiaSourceHash,
    nvidiaUtilsUrl: $nvidiaUtilsUrl,
    nvidiaUtilsFilename: $nvidiaUtilsFilename,
    nvidiaUtilsSha256: $nvidiaUtilsSha256,
    nvidiaUtilsHash: $nvidiaUtilsHash
  }' > "$HASHES_FILE"

printf 'Updated gpu-unlock-ada to %s (firmware: %s)\n' "$VERSION" "$FIRMWARE_VERSION"
