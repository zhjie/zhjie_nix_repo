{
  lib,
  fetchFromGitHub,
  melpaBuild,
  nix-update-script,
  stdenv,
  zig_0_15,
  emacs,
}:

let
  hashes = lib.importJSON ./hashes.json;
  zig = zig_0_15;
  pname = "ghostel";
  version = hashes.version;

  src = fetchFromGitHub {
    owner = "dakra";
    repo = "ghostel";
    rev = hashes.rev;
    hash = hashes.sourceHash;
  };

  module = stdenv.mkDerivation (finalAttrs: {
    inherit pname version src;

    deps = zig.fetchDeps {
      inherit (finalAttrs) src pname version;
      fetchAll = true;
      hash = hashes.zigDepsHash;
    };

    nativeBuildInputs = [ zig ];

    env.EMACS_INCLUDE_DIR = "${emacs}/include";

    dontSetZigDefaultFlags = true;

    doCheck = true;

    zigCheckFlags = [
      "-Dcpu=baseline"
      "-Doptimize=ReleaseFast"
    ];

    zigBuildFlags = finalAttrs.zigCheckFlags;

    postConfigure = ''
      cp -rLT ${finalAttrs.deps} "$ZIG_GLOBAL_CACHE_DIR/p"
      chmod -R u+w "$ZIG_GLOBAL_CACHE_DIR/p"

      substituteInPlace "$ZIG_GLOBAL_CACHE_DIR"/p/ghostty-*/build.zig \
        --replace-fail '    const bench = try buildpkg.GhosttyBench.init(b, &deps);' '    if (config.emit_bench) {
          const bench = try buildpkg.GhosttyBench.init(b, &deps);' \
        --replace-fail '    if (config.emit_bench) bench.install();' '        bench.install();
      }'
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      substituteInPlace build.zig \
        --replace-fail '.macos => "ghostel-module.dylib",' \
                       '.macos => "lib/ghostel-module.dylib",'
    '';
  });

  libExt = stdenv.hostPlatform.extensions.sharedLibrary;
  moduleFile =
    if stdenv.hostPlatform.isDarwin then
      "${module}/lib/ghostel-module${libExt}"
    else
      "${module}/ghostel-module${libExt}";
in
melpaBuild {
  inherit pname version src;

  files = ''
    (:defaults "etc" "ghostel-module${libExt}")
  '';

  preBuild = ''
    install ${moduleFile} ghostel-module${libExt}
  '';

  passthru = {
    updateScript = nix-update-script { extraArgs = [ "--version=branch=main" ]; };
    inherit module;
  };

  meta = {
    homepage = "https://github.com/dakra/ghostel";
    description = "Terminal emulator powered by libghostty";
    license = lib.licenses.gpl3Plus;
    changelog = "https://github.com/dakra/ghostel/releases/tag/v${version}";
  };
}
