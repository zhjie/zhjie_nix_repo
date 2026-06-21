{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  jq,
}:

let
  hashes = lib.importJSON ./hashes.json;
  version = hashes.version;

  srcWithLock = runCommand "docx-src-with-lock" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/docx/-/docx-${version}.tgz";
        hash = hashes.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
    jq 'del(.devDependencies)' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
  '';
in
buildNpmPackage {
  pname = "docx";
  inherit version;

  src = srcWithLock;

  npmDepsHash = hashes.npmDepsHash;
  makeCacheWritable = true;

  npmFlags = [
    "--legacy-peer-deps"
    "--omit=dev"
    "--ignore-scripts"
  ];

  dontNpmBuild = true;

  postInstall = ''
    mkdir -p $out/bin
    cat <<EOF > $out/bin/docx
    #!/usr/bin/env bash
    export NODE_PATH="$out/lib/node_modules:\$NODE_PATH"
    if [ "\$#" -eq 0 ]; then
      exec node -e "const docx = require('docx'); console.log('docx library loaded successfully.');"
    else
      exec node "\$@"
    fi
    EOF
    chmod +x $out/bin/docx
  '';

  meta = {
    description = "A developer friendly library to generate docx files";
    homepage = "https://docx.js.org/";
    changelog = "https://github.com/dolanmiu/docx/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "docx";
    platforms = lib.platforms.all;
  };
}
