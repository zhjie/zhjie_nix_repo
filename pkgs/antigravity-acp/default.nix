{
  lib,
  stdenv,
  fetchurl,
  unzip,
  makeWrapper,
}:

let
  hashes = lib.importJSON ./hashes.json;
  system = stdenv.hostPlatform.system;

  source =
    hashes.sources.${system}
      or (throw "antigravity-acp is not supported on platform: ${system}");
in
stdenv.mkDerivation {
  pname = "antigravity-acp";
  version = hashes.version;

  src = fetchurl {
    url = source.url;
    hash = source.hash;
  };

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/antigravity-acp $out/bin
    unzip -q $src -d $out/libexec/antigravity-acp
    chmod +x $out/libexec/antigravity-acp/*

    makeWrapper $out/libexec/antigravity-acp/agy_acp_server.par $out/bin/antigravity-acp \
      --prefix PATH : "$out/libexec/antigravity-acp"

    makeWrapper $out/libexec/antigravity-acp/agy_acp_server.par $out/bin/agy_acp_server.par \
      --prefix PATH : "$out/libexec/antigravity-acp"

    runHook postInstall
  '';

  meta = {
    description = "Google Antigravity ACP server binary";
    homepage = "https://antigravity.google/docs/ide/extensions";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "antigravity-acp";
  };
}
