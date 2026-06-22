# Design Spec: Emacs codex-ide Package Integration

This document outlines the design for integrating `emacs-codex-ide` into the Nix configuration. It mimics the structure of `claude-code-ide`.

## Goal

Add the Emacs package `codex-ide` (from [dgillis/emacs-codex-ide](https://github.com/dgillis/emacs-codex-ide)) to the Nix packages repository.

## Package Architecture

The package will be defined under `pkgs/codex-ide` with three key files:

1. `pkgs/codex-ide/default.nix`: The Nix derivation using `melpaBuild`.
2. `pkgs/codex-ide/hashes.json`: Pinning info (`version`, `rev`, and `sourceHash`).
3. `pkgs/codex-ide/update.sh`: Individual package update script to fetch the latest commit, parse upstream version, prefetch source hash, and update `hashes.json`.

We will also update:
1. `flake.nix`: Expose `codex-ide` package under `packages.<system>`.
2. `update.sh` (workspace root): Register `codex-ide` in the global update list and add it to dry-run builds.

---

## Detailed Specifications

### 1. Nix Derivation (`pkgs/codex-ide/default.nix`)

```nix
{
  lib,
  fetchFromGitHub,
  melpaBuild,
  transient,
}:

let
  hashes = lib.importJSON ./hashes.json;
in
melpaBuild {
  pname = "codex-ide";
  version = hashes.version;

  src = fetchFromGitHub {
    owner = "dgillis";
    repo = "emacs-codex-ide";
    rev = hashes.rev;
    hash = hashes.sourceHash;
  };

  packageRequires = [
    transient
  ];

  meta = {
    description = "Codex app-server integration for Emacs";
    homepage = "https://github.com/dgillis/emacs-codex-ide";
    license = lib.licenses.gpl3Plus;
  };
}
```

### 2. Pins / Hashes JSON (`pkgs/codex-ide/hashes.json`)

Initially, this file will contain the latest commit info and will be updated by the update script.

```json
{
  "version": "",
  "rev": "",
  "sourceHash": ""
}
```

### 3. Update Script (`pkgs/codex-ide/update.sh`)

This script mimics the `claude-code-ide` update script:
- Queries the GitHub API for the latest commit SHA and committer date of the `main` branch.
- Queries the GitHub API to fetch `codex-ide.el` and extract the version defined in `;; Version:`.
- Prefetches the unpack archive hash using `nix store prefetch-file`.
- Updates `hashes.json`.

```bash
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

if [ "$CURRENT_REV" = "$REV" ] && jq -e '.version and .sourceHash' "$HASHES_FILE" >/dev/null 2>&1; then
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
```

---

## Verification Criteria

To verify the integration, we will run the global update script and verify the package builds:
1. `nix eval .#packages.x86_64-darwin` should include `codex-ide` in the list of attributes.
2. `nix build --dry-run .#packages.x86_64-darwin.codex-ide` should evaluate successfully.
3. Verification command should pass without errors.
