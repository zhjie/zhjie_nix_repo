{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
}:

let
  hashes = lib.importJSON ./hashes.json;
  version = hashes.version;

  srcWithLock = runCommand "pi-acp-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/pi-acp/-/pi-acp-${version}.tgz";
        hash = hashes.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "pi-acp";
  inherit version;

  src = srcWithLock;

  npmDepsHash = hashes.npmDepsHash;
  makeCacheWritable = true;

  npmFlags = [ "--ignore-scripts" ];

  dontNpmBuild = true;

  meta = {
    description = "ACP adapter for pi coding agent";
    homepage = "https://github.com/svkozak/pi-acp";
    changelog = "https://github.com/svkozak/pi-acp/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "pi-acp";
    platforms = lib.platforms.all;
  };
}
