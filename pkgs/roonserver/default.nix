{
  autoPatchelfHook,
  fetchurl,
  icu66,
  lib,
  makeWrapper,
  openssl,
  stdenv,
}:
let
  hashes = lib.importJSON ./hashes.json;
  version = hashes.version;
  urlVersion = builtins.replaceStrings [ "." ] [ "0" ] version;
in
stdenv.mkDerivation {
  pname = "roon-server";
  inherit version;

  src = fetchurl {
    url = "https://download.roonlabs.com/updates/production/RoonServer_linuxx64_${urlVersion}.tar.bz2";
    hash = hashes.sourceHash;
  };

  dontConfigure = true;
  dontBuild = true;

  buildInputs = [
    (lib.getLib stdenv.cc.cc)
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libasound.so.2"
  ];

  installPhase =
    let
      wrapBin = binPath: ''
        (
          binDir="$(dirname "${binPath}")"
          binName="$(basename "${binPath}")"
          dotnetDir="$out/RoonDotnet"

          ln -sf "$dotnetDir/dotnet" "$dotnetDir/$binName"
          rm "${binPath}"
          makeWrapper "$dotnetDir/$binName" "${binPath}" \
            --add-flags "$binDir/$binName.dll" \
            --argv0 "$binName" \
            --prefix LD_LIBRARY_PATH : "${
              lib.makeLibraryPath [
                icu66
                openssl
              ]
            }" \
            --prefix PATH : "$dotnetDir" \
            --prefix PATH : "${
              lib.makeBinPath [
              ]
            }" \
            --chdir "$binDir" \
            --set DOTNET_ROOT "$dotnetDir"
        )
      '';
    in
    ''
      runHook preInstall

      mkdir -p $out
      mv * $out

      rm $out/Appliance/roon_smb_watcher
      rm $out/*/*.otf
      rm $out/*/*.ttf
      rm -rf $out/Appliance/webroot
      rm $out/Appliance/libharfbuzz.so
      rm $out/Appliance/check_alsa
      rm $out/RoonDotnet/shared/Microsoft.NETCore.App/*/libcoreclrtraceptprovider.so

      rm $out/check.sh
      rm $out/start.sh
      rm $out/VERSION

      ${wrapBin "$out/Appliance/RAATServer"}
      ${wrapBin "$out/Appliance/RoonAppliance"}
      ${wrapBin "$out/Server/RoonServer"}

      mkdir -p $out/bin
      makeWrapper "$out/Server/RoonServer" "$out/bin/RoonServer" --chdir "$out"

      runHook postInstall
    '';

  meta = {
    description = "Music player for music lovers";
    homepage = "https://roonlabs.com";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "RoonServer";
  };
}
