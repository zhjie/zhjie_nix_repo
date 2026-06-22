# Emacs codex-ide Package Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Emacs package `codex-ide` to the Nix packages monorepo, following the layout of `claude-code-ide.el`.

**Architecture:** Create `pkgs/codex-ide/default.nix`, `pkgs/codex-ide/hashes.json`, and `pkgs/codex-ide/update.sh`. Integrate into `flake.nix` and the global `update.sh`.

**Tech Stack:** Nix, Bash, GitHub API, Emacs packages infrastructure.

---

### Task 1: Create hash pin placeholder

**Files:**
- Create: `pkgs/codex-ide/hashes.json`

- [ ] **Step 1: Write placeholder hashes.json**
  Write an empty JSON object to `pkgs/codex-ide/hashes.json` to allow the update script and Nix to read/write it.
  
  Code for `pkgs/codex-ide/hashes.json`:
  ```json
  {
    "version": "",
    "rev": "",
    "sourceHash": ""
  }
  ```

- [ ] **Step 2: Commit placeholder hashes.json**
  Run command:
  ```bash
  git add pkgs/codex-ide/hashes.json
  git commit -m "chore: create hashes.json placeholder for codex-ide"
  ```

---

### Task 2: Create individual update script

**Files:**
- Create: `pkgs/codex-ide/update.sh`

- [ ] **Step 1: Write update.sh script**
  Create `pkgs/codex-ide/update.sh` which queries the GitHub API for the latest commit of `dgillis/emacs-codex-ide`, parses `codex-ide.el` for version, and computes the unpack archive hash.

  Code for `pkgs/codex-ide/update.sh`:
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

- [ ] **Step 2: Make update.sh executable**
  Run: `chmod +x pkgs/codex-ide/update.sh`

- [ ] **Step 3: Commit update.sh**
  Run:
  ```bash
  git add pkgs/codex-ide/update.sh
  git commit -m "feat: add update.sh script for codex-ide"
  ```

---

### Task 3: Create default.nix derivation

**Files:**
- Create: `pkgs/codex-ide/default.nix`

- [ ] **Step 1: Write default.nix**
  Create `pkgs/codex-ide/default.nix` using `melpaBuild` and adding `transient` as dependency.

  Code for `pkgs/codex-ide/default.nix`:
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

- [ ] **Step 2: Commit default.nix**
  Run:
  ```bash
  git add pkgs/codex-ide/default.nix
  git commit -m "feat: add default.nix derivation for codex-ide"
  ```

---

### Task 4: Run package update.sh to fetch hashes

**Files:**
- Modify: `pkgs/codex-ide/hashes.json`

- [ ] **Step 1: Run update.sh**
  Run the individual update script:
  ```bash
  ./pkgs/codex-ide/update.sh
  ```
  Expected: Success output like "Updated codex-ide to ...". Verify `hashes.json` is updated with actual values.

- [ ] **Step 2: Commit hashes.json updates**
  Run:
  ```bash
  git add pkgs/codex-ide/hashes.json
  git commit -m "chore: fetch latest hashes.json for codex-ide"
  ```

---

### Task 5: Register package in flake.nix

**Files:**
- Modify: `flake.nix`

- [ ] **Step 1: Add codex-ide package in flake.nix**
  Add `codex-ide` definition under packages attribute set in `flake.nix`.
  
  In `flake.nix` (around line 26):
  ```nix
  packages = {
    claude-code-ide = pkgs.emacsPackages.callPackage ./pkgs/claude-code-ide { };
    codex-ide = pkgs.emacsPackages.callPackage ./pkgs/codex-ide { };
    docx = pkgs.callPackage ./pkgs/docx { };
  ```

- [ ] **Step 2: Commit flake.nix changes**
  Run:
  ```bash
  git add flake.nix
  git commit -m "feat: expose codex-ide in flake.nix"
  ```

---

### Task 6: Register package in global update.sh

**Files:**
- Modify: `update.sh`

- [ ] **Step 1: Add package to update.sh**
  Add `codex-ide` to the list of packages to update and verify.
  
  In `update.sh` (around line 8-16):
  ```bash
  PACKAGES=(
    claude-code-ide
    codex-ide
    docx
    ghostel
    pi-acp
    pptxgenjs
    qterm
    roonserver
  )
  ```
  
  And add it to verification list (around line 30-36):
  ```bash
  nix build --dry-run \
    "$ROOT#packages.${SYSTEM}.claude-code-ide" \
    "$ROOT#packages.${SYSTEM}.codex-ide" \
    "$ROOT#packages.${SYSTEM}.docx" \
  ```

- [ ] **Step 2: Commit global update.sh changes**
  Run:
  ```bash
  git add update.sh
  git commit -m "feat: register codex-ide in global update.sh"
  ```

---

### Task 7: Execute global update.sh and verify

**Files:**
- Modify: `flake.lock` (automatic update via nix flake lock)

- [ ] **Step 1: Run global update.sh**
  Run:
  ```bash
  ./update.sh
  ```
  Expected: All package updates succeed, evaluations succeed, and dry-run builds of `codex-ide` and other packages pass.

- [ ] **Step 2: Commit lock file updates if any**
  Run:
  ```bash
  git add flake.lock || true
  git commit -m "chore: update flake lock file" || true
  ```
