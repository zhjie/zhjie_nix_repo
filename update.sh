#!/usr/bin/env bash
# Update every maintained package and verify the flake locally.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
SYSTEM="${SYSTEM:-$(nix eval --raw --impure --expr builtins.currentSystem)}"

PACKAGES=(
  claude-code-ide
  docx
  ghostel
  pi-acp
  pptxgenjs
  qterm
  roonserver
)

for package in "${PACKAGES[@]}"; do
  printf '\n==> Updating %s\n' "$package"
  "$ROOT/pkgs/$package/update.sh"
done

printf '\n==> Updating flake.lock\n'
(cd "$ROOT" && nix flake lock)

printf '\n==> Verifying package evaluation on %s\n' "$SYSTEM"
nix eval "$ROOT#packages.${SYSTEM}" --apply builtins.attrNames

printf '\n==> Verifying dry-run builds on %s\n' "$SYSTEM"
nix build --dry-run \
  "$ROOT#packages.${SYSTEM}.claude-code-ide" \
  "$ROOT#packages.${SYSTEM}.docx" \
  "$ROOT#packages.${SYSTEM}.ghostel" \
  "$ROOT#packages.${SYSTEM}.pi-acp" \
  "$ROOT#packages.${SYSTEM}.pptxgenjs"

if [ "$SYSTEM" = "x86_64-linux" ]; then
  nix build --dry-run \
    "$ROOT#packages.${SYSTEM}.qterm" \
    "$ROOT#packages.${SYSTEM}.roon-server"
fi

printf '\nAll package updates and local verification completed.\n'
