{
  autoPatchelfHook,
  fetchurl,
  icu,
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
    icu
    openssl
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

          rm -f "${binPath}"
          makeWrapper "$binDir/$binName.exe" "${binPath}" \
            --argv0 "$binName" \
            --prefix LD_LIBRARY_PATH : "${
              lib.makeLibraryPath [
                icu
                openssl
              ]
            }" \
            --chdir "$binDir"
        )
      '';
    in
    ''
      runHook preInstall

      mkdir -p $out
      mv * $out

      rm -f $out/Appliance/roon_smb_watcher
      rm -f $out/*/*.otf
      rm -f $out/*/*.ttf
      rm -rf $out/Appliance/webroot
      rm -f $out/Appliance/libharfbuzz.so
      rm -f $out/Appliance/check_alsa
      rm -f $out/Server/libcoreclrtraceptprovider.so
      rm -f $out/Appliance/libcoreclrtraceptprovider.so

      rm -f $out/check-common.sh
      rm -f $out/check.sh
      rm -f $out/start.sh
      rm -f $out/VERSION

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
