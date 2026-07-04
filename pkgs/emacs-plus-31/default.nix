{
  lib,
  pkgs,
  fetchurl,
  fetchgit,
  fetchpatch,
}:

let
  hashes = lib.importJSON ./hashes.json;
  emacs31 = pkgs.callPackage (
    import "${pkgs.path}/pkgs/applications/editors/emacs/make-emacs.nix" {
      pname = "emacs";
      version = "31.0.90-unstable-2026-07-03";
      variant = "mainline";
      src = fetchgit {
        url = "https://github.com/emacs-mirror/emacs.git";
        rev = "7d01f8f7a4e1b2a5608d2c866309ef4074ecf404";
        branchName = "emacs-31";
        hash = "sha256-EqvTpBbBT/MSLqfVfwXfU3HHqxe80YIggCFQ66gl9y4=";
      };
      meta = {
        homepage = "https://www.gnu.org/software/emacs/";
        description = "Extensible, customizable GNU text editor";
        changelog = "https://cgit.git.savannah.gnu.org/cgit/emacs.git/plain/etc/NEWS?h=7d01f8f7a4e1b2a5608d2c866309ef4074ecf404";
        license = lib.licenses.gpl3Plus;
        platforms = lib.platforms.all;
        mainProgram = "emacs";
      };
    }
  ) {
    inherit (pkgs.darwin) sigtool;
    srcRepo = true;
  };
in
emacs31.overrideAttrs (oldAttrs: {
  pname = "emacs-plus";

  # Inject macOS file descriptor optimizations (prevents "too many open files" errors in LSP/Doom Emacs)
  NIX_CFLAGS_COMPILE =
    (oldAttrs.NIX_CFLAGS_COMPILE or "") + " -DFD_SETSIZE=10000 -DDARWIN_UNLIMITED_SELECT -mcpu=native";

  # 1. Apply all patches defined in hashes.json after nixpkgs' Emacs patches.
  patches =
    (oldAttrs.patches or [ ])
    ++ (map (
      name:
      fetchpatch {
        inherit (hashes.patches.${name}) url;
        hash = hashes.patches.${name}.hash;
      }
    ) (builtins.attrNames hashes.patches));

  # 2. Inject custom icons (dragon-plus)
  postInstall = (oldAttrs.postInstall or "") + ''
    echo "Installing custom dragon-plus icons..."

    # 1. Copy icon.icns
    cp ${
      fetchurl {
        inherit (hashes.icon.icns) url;
        hash = hashes.icon.icns.hash;
      }
    } $out/Applications/Emacs.app/Contents/Resources/Emacs.icns

    # 2. Copy Assets.car (required for modern macOS Sonoma/Tahoe theme integration)
    cp ${
      fetchurl {
        inherit (hashes.icon.assets) url;
        hash = hashes.icon.assets.hash;
      }
    } $out/Applications/Emacs.app/Contents/Resources/Assets.car

    /usr/libexec/PlistBuddy -c "Delete :CFBundleDisplayName" "$out/Applications/Emacs.app/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Emacs" "$out/Applications/Emacs.app/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$out/Applications/Emacs.app/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string dragon" "$out/Applications/Emacs.app/Contents/Info.plist"
  '';

  meta = oldAttrs.meta // {
    description = "GNU Emacs 31 with patches from emacs-plus (including mac-font-use-typo-metrics and aggressive-read-buffering)";
    homepage = "https://github.com/d12frosted/homebrew-emacs-plus";
  };
})
