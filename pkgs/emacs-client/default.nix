{
  lib,
  fetchurl,
  stdenv,
  emacs-plus,
}:

let
  hashes = lib.importJSON ../emacs-plus/hashes.json;
in
stdenv.mkDerivation {
  pname = "emacs-client-app";
  version = emacs-plus.version;

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/Applications
    clientApp="$out/Applications/Emacs Client.app"
    clientPlist="$clientApp/Contents/Info.plist"
    clientResources="$clientApp/Contents/Resources"
    clientScript="$PWD/emacs-client.applescript"
    clientPath="/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    emacsApp="${emacs-plus}/Applications/Emacs.app"
    emacsclient="${emacs-plus}/bin/emacsclient"

    plist_set() {
      key="$1"
      type="$2"
      value="$3"
      /usr/libexec/PlistBuddy -c "Add :$key $type $value" "$clientPlist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set :$key $value" "$clientPlist"
    }

    echo "Compiling Emacs Client.app using osacompile..."
    cat > "$clientScript" <<EOF
      -- Emacs Client AppleScript Application
      -- Handles opening files from Finder, drag-and-drop, and launching from Spotlight/Dock

      on runClient(clientArgs, fallbackArgs)
        try
          do shell script "PATH='$clientPath' '$emacsclient' " & clientArgs
        on error
          do shell script "open " & quoted form of "$emacsApp"
          if fallbackArgs is not "" then
            repeat 50 times
              try
                do shell script "PATH='$clientPath' '$emacsclient' " & fallbackArgs
                return
              end try
              delay 0.1
            end repeat
            do shell script "PATH='$clientPath' '$emacsclient' " & fallbackArgs
          end if
        end try
      end runClient

      on activateEmacsIfRunning()
        if application "Emacs" is running then
          tell application "Emacs" to activate
        end if
      end activateEmacsIfRunning

      on open the_files
        repeat with the_file in the_files
          set dropPath to quoted form of (POSIX path of the_file)
          my runClient("-c -n " & dropPath, "-n " & dropPath)
        end repeat
        my activateEmacsIfRunning()
      end open

      -- Handle launch without files (from Spotlight, Dock, or Finder)
      on run
        my runClient("-c -n", "")
        my activateEmacsIfRunning()
      end run

      -- Handle org-protocol:// URLs (for org-capture, org-roam, etc.)
      on open location the_url
        my runClient("-n " & quoted form of the_url, "-n " & quoted form of the_url)
        my activateEmacsIfRunning()
      end open location
    EOF

    /usr/bin/osacompile -o "$clientApp" "$clientScript"

    echo "Updating Info.plist..."
    plist_set CFBundleIdentifier string org.gnu.EmacsClient
    plist_set CFBundleName string "Emacs Client"
    plist_set CFBundleDisplayName string "Emacs Client"
    plist_set CFBundleGetInfoString string "Emacs Client ${emacs-plus.version}"
    plist_set CFBundleVersion string "${emacs-plus.version}"
    plist_set CFBundleShortVersionString string "${emacs-plus.version}"
    plist_set LSApplicationCategoryType string public.app-category.productivity
    plist_set NSHumanReadableCopyright string "Copyright 1989-2026 Free Software Foundation, Inc."

    /usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$clientPlist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Text Document" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string public.text" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.plain-text" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:2 string public.source-code" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:3 string public.script" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:4 string public.shell-script" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:5 string public.data" "$clientPlist"

    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string Org Protocol" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string org-protocol" "$clientPlist"

    echo "Installing custom dragon icons and Assets.car..."
    cp ${
      fetchurl {
        inherit (hashes.icon.icns) url;
        hash = hashes.icon.icns.hash;
      }
    } "$clientResources/applet.icns"
    rm -f "$clientResources/droplet.icns" "$clientResources/droplet.rsrc" "$clientResources/Assets.car"
    cp ${
      fetchurl {
        inherit (hashes.icon.assets) url;
        hash = hashes.icon.assets.hash;
      }
    } "$clientResources/Assets.car"
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$clientPlist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string dragon" "$clientPlist"
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$clientPlist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string applet" "$clientPlist"
  '';

  meta = {
    description = "macOS native launcher wrapper for EmacsClient";
    homepage = "https://github.com/d12frosted/homebrew-emacs-plus";
    platforms = lib.platforms.darwin;
  };
}
