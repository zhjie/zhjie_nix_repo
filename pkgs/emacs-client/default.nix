{
  lib,
  stdenv,
  emacs-plus,
}:

stdenv.mkDerivation {
  pname = "emacs-client-app";
  version = emacs-plus.version;

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/Applications
    
    echo "Compiling Emacs Client.app using osacompile..."
    /usr/bin/osacompile -o "$out/Applications/Emacs Client.app" -e '
      on open the_files
        repeat with the_file in the_files
          do shell script "/run/current-system/sw/bin/emacsclient -c -n -a \"\" " & quoted form of (POSIX path of the_file)
        end repeat
        tell application "Emacs" to activate
      end open

      on open location the_url
        do shell script "/run/current-system/sw/bin/emacsclient -n -a \"\" " & quoted form of the_url
        tell application "Emacs" to activate
      end open location
    '

    echo "Registering org-protocol in Info.plist..."
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes list" "$out/Applications/Emacs Client.app/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$out/Applications/Emacs Client.app/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes list" "$out/Applications/Emacs Client.app/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string org-protocol" "$out/Applications/Emacs Client.app/Contents/Info.plist" 2>/dev/null || true

    echo "Copying custom dragon icon from emacs-plus..."
    cp "${emacs-plus}/Applications/Emacs.app/Contents/Resources/Emacs.icns" "$out/Applications/Emacs Client.app/Contents/Resources/applet.icns"
  '';

  meta = {
    description = "macOS native launcher wrapper for EmacsClient";
    homepage = "https://github.com/d12frosted/homebrew-emacs-plus";
    platforms = lib.platforms.darwin;
  };
}
