#!/usr/bin/env bash
# Update pkgs/antigravity-acp from ACP registry agent.json.
#
# Usage:
#   pkgs/antigravity-acp/update.sh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
HASHES_FILE="$SCRIPT_DIR/hashes.json"
REGISTRY_URL="https://raw.githubusercontent.com/agentclientprotocol/registry/main/antigravity-acp/agent.json"

printf 'Fetching registry metadata from %s...\n' "$REGISTRY_URL"
AGENT_JSON="$(curl -fsSL "$REGISTRY_URL")"

URL_DARWIN_ARM64="$(printf '%s\n' "$AGENT_JSON" | jq -r '.distribution.binary."darwin-aarch64".archive')"
URL_LINUX_X64="$(printf '%s\n' "$AGENT_JSON" | jq -r '.distribution.binary."linux-x86_64".archive')"
URL_LINUX_ARM64="$(printf '%s\n' "$AGENT_JSON" | jq -r '.distribution.binary."linux-aarch64".archive')"

if [ -z "$URL_DARWIN_ARM64" ] || [ "$URL_DARWIN_ARM64" = "null" ]; then
  printf 'Error: missing darwin-aarch64 archive URL in registry\n' >&2
  exit 1
fi

VERSION="$(printf '%s\n' "$URL_DARWIN_ARM64" | sed -nE 's/.*agy_acp_server_([0-9A-Za-z_]+)-.*/\1/p')"
if [ -z "$VERSION" ]; then
  VERSION="$(printf '%s\n' "$AGENT_JSON" | jq -r '.version')"
fi

CURRENT="$(jq -r '.version' "$HASHES_FILE" 2>/dev/null || echo "0.0.0")"
printf 'Current: %s  Latest: %s\n' "$CURRENT" "$VERSION"

printf 'Fetching hashes...\n'
printf '  aarch64-darwin...\n'
HASH_DARWIN_ARM64="$(nix store prefetch-file --json "$URL_DARWIN_ARM64" | jq -r '.hash')"
printf '    %s\n' "$HASH_DARWIN_ARM64"

printf '  x86_64-linux...\n'
HASH_LINUX_X64="$(nix store prefetch-file --json "$URL_LINUX_X64" | jq -r '.hash')"
printf '    %s\n' "$HASH_LINUX_X64"

printf '  aarch64-linux...\n'
HASH_LINUX_ARM64="$(nix store prefetch-file --json "$URL_LINUX_ARM64" | jq -r '.hash')"
printf '    %s\n' "$HASH_LINUX_ARM64"

jq -n \
  --arg version "$VERSION" \
  --arg url_darwin_arm64 "$URL_DARWIN_ARM64" \
  --arg hash_darwin_arm64 "$HASH_DARWIN_ARM64" \
  --arg url_linux_x64 "$URL_LINUX_X64" \
  --arg hash_linux_x64 "$HASH_LINUX_X64" \
  --arg url_linux_arm64 "$URL_LINUX_ARM64" \
  --arg hash_linux_arm64 "$HASH_LINUX_ARM64" \
  '{
    version: $version,
    sources: {
      "aarch64-darwin": {
        url: $url_darwin_arm64,
        hash: $hash_darwin_arm64
      },
      "x86_64-linux": {
        url: $url_linux_x64,
        hash: $hash_linux_x64
      },
      "aarch64-linux": {
        url: $url_linux_arm64,
        hash: $hash_linux_arm64
      }
    }
  }' > "$HASHES_FILE"

printf 'Updated antigravity-acp to %s\n' "$VERSION"
