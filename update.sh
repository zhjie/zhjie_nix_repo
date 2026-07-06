#!/usr/bin/env bash
# Update maintained packages, verify the flake locally, and refresh README.md.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
SYSTEM="${SYSTEM:-$(nix eval --raw --impure --expr builtins.currentSystem)}"
README_FILE="$ROOT/README.md"

DRY_RUN=0
README_ONLY=0

usage() {
  printf 'Usage: %s [--dry-run] [--readme-only]\n' "${0##*/}"
  printf '\n'
  printf '  --dry-run      Check package status without updating files.\n'
  printf '  --readme-only  Refresh README.md from the current package status.\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --readme-only)
      README_ONLY=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$DRY_RUN" -eq 1 ] && [ "$README_ONLY" -eq 1 ]; then
  printf 'Error: --dry-run and --readme-only cannot be used together.\n' >&2
  exit 2
fi

# name | package directory | flake attribute | upstream checker | checker argument | maintenance
PACKAGES=(
  "emacs-plus|emacs-plus|emacs-plus|patches||Auto"
  "emacs-plus-31|emacs-plus-31|emacs-plus-31|patches||Auto"
  "claude-code-ide|claude-code-ide|claude-code-ide|el-head|manzaltu/claude-code-ide.el/claude-code-ide.el|Auto"
  "codex-ide|codex-ide|codex-ide|el-head|dgillis/emacs-codex-ide/codex-ide.el|Auto"
  "docx|docx|docx|npm|docx|Auto"
  "ghostel|ghostel|ghostel|git-tag-v|https://github.com/dakra/ghostel.git|Auto"
  "evil-ghostel|evil-ghostel|evil-ghostel|git-tag-v|https://github.com/dakra/ghostel.git|Auto"
  "pi-acp|pi-acp|pi-acp|npm|pi-acp|Auto"
  "pi-coding-agent|pi-coding-agent|pi-coding-agent|npm|@earendil-works/pi-coding-agent|Auto"
  "pptxgenjs|pptxgenjs|pptxgenjs|npm|pptxgenjs|Auto"
  "qterm|qterm|qterm|git-tag|https://github.com/qterm/qterm.git|Auto"
  "roon-server|roonserver|roon-server|roon||Auto"
  "emacs-client|emacs-client|emacs-client|manual|1.0|Manual"
)

RESULT_PACKAGES=()
RESULT_ATTRS=()
RESULT_LOCAL=()
RESULT_UPSTREAM=()
RESULT_STATUS=()
RESULT_MAINTENANCE=()

package_field() {
  local row="$1"
  local index="$2"
  IFS='|' read -r f0 f1 f2 f3 f4 f5 <<EOF
$row
EOF
  case "$index" in
    0) printf '%s\n' "$f0" ;;
    1) printf '%s\n' "$f1" ;;
    2) printf '%s\n' "$f2" ;;
    3) printf '%s\n' "$f3" ;;
    4) printf '%s\n' "$f4" ;;
    5) printf '%s\n' "$f5" ;;
  esac
}

hashes_version() {
  local dir="$1"
  local fallback="$2"
  local file="$ROOT/pkgs/$dir/hashes.json"
  if [ -f "$file" ]; then
    jq -r --arg fallback "$fallback" '.version // $fallback' "$file" 2>/dev/null
  else
    printf '%s\n' "$fallback"
  fi
}

hashes_rev() {
  local dir="$1"
  local file="$ROOT/pkgs/$dir/hashes.json"
  if [ -f "$file" ]; then
    jq -r '.rev // ""' "$file" 2>/dev/null
  else
    printf '\n'
  fi
}

latest_npm() {
  curl -fsSL "https://registry.npmjs.org/$1/latest" | jq -r '.version'
}

latest_git_tag() {
  local url="$1"
  local prefix="$2"
  git ls-remote --tags --refs "$url" "refs/tags/${prefix}*" \
    | sed -nE "s#^([^[:space:]]+)[[:space:]]+refs/tags/${prefix}([0-9].*)#\1\t\2#p" \
    | sort -t$'\t' -k2,2V \
    | tail -n1
}

latest_el_head() {
  local spec="$1"
  local owner_repo="${spec%/*}"
  local file="${spec##*/}"
  local owner="${owner_repo%%/*}"
  local repo="${owner_repo#*/}"
  local remote="https://github.com/${owner}/${repo}.git"
  local rev
  local commit_date
  local package_el
  local upstream_version

  rev="$(git ls-remote "$remote" HEAD | cut -f1)"
  commit_date="$(gh api "repos/${owner}/${repo}/commits/${rev}" --jq '.commit.committer.date[0:10]')"
  package_el="$(gh api "repos/${owner}/${repo}/contents/${file}?ref=${rev}" --jq '.content' | base64 --decode)"
  upstream_version="$(printf '%s\n' "$package_el" | sed -nE 's/^;; Version:[[:space:]]*([^[:space:]]+).*/\1/p' | head -n1)"

  if [ -z "$upstream_version" ]; then
    return 1
  fi
  printf '%s\t%s-unstable-%s\n' "$rev" "$upstream_version" "$commit_date"
}

latest_roon() {
  local response
  local display_version
  response="$(curl -fsSL "https://updates.roonlabs.net/update/?v=2&platform=linux&version=&product=RoonServer&branding=roon&branch=production&curbranch=production")"

  if [[ "$response" =~ displayversion=([^\r\n]+) ]]; then
    display_version="${BASH_REMATCH[1]}"
  else
    return 1
  fi

  if [[ "$display_version" =~ ([0-9]+\.[0-9]+)[[:space:]]+\(build[[:space:]]+([0-9]+)\) ]]; then
    printf '%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  else
    return 1
  fi
}

check_package() {
  local row="$1"
  local name dir attr checker arg maintenance
  local local_version local_rev upstream_version upstream_rev status latest_line

  name="$(package_field "$row" 0)"
  dir="$(package_field "$row" 1)"
  attr="$(package_field "$row" 2)"
  checker="$(package_field "$row" 3)"
  arg="$(package_field "$row" 4)"
  maintenance="$(package_field "$row" 5)"

  local_version="$(hashes_version "$dir" "Manual")"
  local_rev="$(hashes_rev "$dir")"
  upstream_version="Unknown"
  upstream_rev=""
  status="Error checking upstream"

  case "$checker" in
    npm)
      if upstream_version="$(latest_npm "$arg" 2>/dev/null)"; then
        status="Update available"
        [ "$local_version" = "$upstream_version" ] && status="Up to date"
      fi
      ;;
    git-tag)
      if latest_line="$(latest_git_tag "$arg" "" 2>/dev/null)" && [ -n "$latest_line" ]; then
        upstream_rev="${latest_line%%$'\t'*}"
        upstream_version="${latest_line##*$'\t'}"
        status="Update available"
        [ "$local_version" = "$upstream_version" ] && status="Up to date"
      fi
      ;;
    git-tag-v)
      if latest_line="$(latest_git_tag "$arg" "v" 2>/dev/null)" && [ -n "$latest_line" ]; then
        upstream_rev="${latest_line%%$'\t'*}"
        upstream_version="${latest_line##*$'\t'}"
        status="Update available"
        [ "$local_version" = "$upstream_version" ] && status="Up to date"
      fi
      ;;
    el-head)
      if latest_line="$(latest_el_head "$arg" 2>/dev/null)" && [ -n "$latest_line" ]; then
        upstream_rev="${latest_line%%$'\t'*}"
        upstream_version="${latest_line##*$'\t'}"
        status="Update available"
        [ "$local_rev" = "$upstream_rev" ] && status="Up to date"
      fi
      ;;
    roon)
      if upstream_version="$(latest_roon 2>/dev/null)"; then
        status="Update available"
        [ "$local_version" = "$upstream_version" ] && status="Up to date"
      fi
      ;;
    patches)
      local_version="$(hashes_version "$dir" "Patch hashes")"
      upstream_version="Patch sources"
      status="Refresh hashes"
      ;;
    manual)
      local_version="$arg"
      upstream_version="Manual"
      status="Manual"
      ;;
  esac

  if [ "$DRY_RUN" -eq 1 ] && [ "$status" = "Update available" ]; then
    status="Update available (dry-run)"
  fi

  RESULT_PACKAGES+=("$name")
  RESULT_ATTRS+=("$attr")
  RESULT_LOCAL+=("$local_version")
  RESULT_UPSTREAM+=("$upstream_version")
  RESULT_STATUS+=("$status")
  RESULT_MAINTENANCE+=("$maintenance")
}

check_packages() {
  local row
  RESULT_PACKAGES=()
  RESULT_ATTRS=()
  RESULT_LOCAL=()
  RESULT_UPSTREAM=()
  RESULT_STATUS=()
  RESULT_MAINTENANCE=()

  for row in "${PACKAGES[@]}"; do
    check_package "$row"
  done
}

print_summary() {
  local i
  printf '\n%s\n' "================================================================================"
  printf '%*s\n' 80 'PACKAGE UPDATE SUMMARY'
  printf '%s\n' "================================================================================"
  printf '%-22s | %-24s | %-24s | %-28s | %s\n' "Package" "Local" "Upstream" "Status/Action" "Maintenance"
  printf '%s\n' "--------------------------------------------------------------------------------"
  for i in "${!RESULT_PACKAGES[@]}"; do
    printf '%-22s | %-24s | %-24s | %-28s | %s\n' \
      "${RESULT_PACKAGES[$i]}" \
      "${RESULT_LOCAL[$i]}" \
      "${RESULT_UPSTREAM[$i]}" \
      "${RESULT_STATUS[$i]}" \
      "${RESULT_MAINTENANCE[$i]}"
  done
  printf '%s\n' "================================================================================"
}

package_homepage() {
  local attr="$1"
  local homepage

  if homepage="$(nix eval --raw "$ROOT#packages.${SYSTEM}.${attr}.meta.homepage" 2>/dev/null)" && [ -n "$homepage" ]; then
    printf '%s\n' "$homepage"
    return 0
  fi

  if [ "$SYSTEM" != "x86_64-linux" ]; then
    if homepage="$(nix eval --raw "$ROOT#packages.x86_64-linux.${attr}.meta.homepage" 2>/dev/null)" && [ -n "$homepage" ]; then
      printf '%s\n' "$homepage"
      return 0
    fi
  fi

  return 1
}

readme_package_label() {
  local name="$1"
  local attr="$2"
  local homepage

  if homepage="$(package_homepage "$attr")"; then
    printf '[%s](%s)\n' "$name" "$homepage"
  else
    printf '%s\n' "$name"
  fi
}

write_readme() {
  local tmp
  local i
  local package_label
  tmp="$(mktemp)"
  {
    printf "# zhjie's personal Nix packages\n\n"
    printf '## Package Update Summary\n\n'
    printf '| Package | Local | Upstream | Status/Action | Maintenance |\n'
    printf '| :--- | :--- | :--- | :--- | :--- |\n'
    for i in "${!RESULT_PACKAGES[@]}"; do
      package_label="$(readme_package_label "${RESULT_PACKAGES[$i]}" "${RESULT_ATTRS[$i]}")"
      printf '| %s | %s | %s | %s | %s |\n' \
        "$package_label" \
        "${RESULT_LOCAL[$i]}" \
        "${RESULT_UPSTREAM[$i]}" \
        "${RESULT_STATUS[$i]}" \
        "${RESULT_MAINTENANCE[$i]}"
    done
  } > "$tmp"
  mv "$tmp" "$README_FILE"
  printf '\n==> Updated README.md\n'
}

run_package_updates() {
  local row dir
  for row in "${PACKAGES[@]}"; do
    dir="$(package_field "$row" 1)"
    if [ -x "$ROOT/pkgs/$dir/update.sh" ]; then
      printf '\n==> Updating %s\n' "$(package_field "$row" 0)"
      "$ROOT/pkgs/$dir/update.sh"
    fi
  done
}

verify_flake() {
  printf '\n==> Updating flake.lock\n'
  (cd "$ROOT" && nix flake lock)

  printf '\n==> Verifying package evaluation on %s\n' "$SYSTEM"
  nix eval "$ROOT#packages.${SYSTEM}" --apply builtins.attrNames

  printf '\n==> Verifying dry-run builds on %s\n' "$SYSTEM"
  nix build --dry-run \
    "$ROOT#packages.${SYSTEM}.emacs-plus" \
    "$ROOT#packages.${SYSTEM}.emacs-plus-31" \
    "$ROOT#packages.${SYSTEM}.claude-code-ide" \
    "$ROOT#packages.${SYSTEM}.codex-ide" \
    "$ROOT#packages.${SYSTEM}.docx" \
    "$ROOT#packages.${SYSTEM}.ghostel" \
    "$ROOT#packages.${SYSTEM}.evil-ghostel" \
    "$ROOT#packages.${SYSTEM}.pi-acp" \
    "$ROOT#packages.${SYSTEM}.pi-coding-agent" \
    "$ROOT#packages.${SYSTEM}.pptxgenjs"

  if [ "$SYSTEM" = "x86_64-linux" ]; then
    nix build --dry-run \
      "$ROOT#packages.${SYSTEM}.qterm" \
      "$ROOT#packages.${SYSTEM}.roon-server"
  fi
}

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'Dry run: checking package status without updating files.\n'
  check_packages
  print_summary
  exit 0
fi

if [ "$README_ONLY" -eq 1 ]; then
  check_packages
  print_summary
  write_readme
  exit 0
fi

run_package_updates
verify_flake
check_packages
print_summary
write_readme

printf '\nAll package updates, README refresh, and local verification completed.\n'
