{
  lib,
  fetchurl,
  fetchpatch,
  emacs30,
}:

let
  hashes = lib.importJSON ./hashes.json;
in
emacs30.overrideAttrs (oldAttrs: {
  pname = "emacs-plus";

  # Inject macOS file descriptor optimizations (prevents "too many open files" errors in LSP/Doom Emacs)
  NIX_CFLAGS_COMPILE =
    (oldAttrs.NIX_CFLAGS_COMPILE or "") + " -DFD_SETSIZE=10000 -DDARWIN_UNLIMITED_SELECT";

  # 1. Apply all patches defined in hashes.json
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
    description = "GNU Emacs 30 with patches from emacs-plus (including mac-font-use-typo-metrics and aggressive-read-buffering)";
    homepage = "https://github.com/d12frosted/homebrew-emacs-plus";
  };
})
