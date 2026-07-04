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

  srcWithLock = runCommand "pptxgenjs-src-with-lock" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/pptxgenjs/-/pptxgenjs-${version}.tgz";
        hash = hashes.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
    jq 'del(.devDependencies)' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
  '';
in
buildNpmPackage {
  pname = "pptxgenjs";
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
    cat <<EOF > $out/bin/pptxgenjs
    #!/usr/bin/env bash
    export NODE_PATH="$out/lib/node_modules:\$NODE_PATH"
    if [ "\$#" -eq 0 ]; then
      exec node -e "const pptx = require('pptxgenjs'); console.log('pptxgenjs library loaded successfully.');"
    else
      exec node "\$@"
    fi
    EOF
    chmod +x $out/bin/pptxgenjs
  '';

  meta = {
    description = "Build PowerPoint presentations with JavaScript";
    homepage = "https://gitbrent.github.io/PptxGenJS/";
    changelog = "https://github.com/gitbrent/PptxGenJS/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "pptxgenjs";
    platforms = lib.platforms.all;
  };
}
