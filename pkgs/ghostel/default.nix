{
  lib,
  fetchFromGitHub,
  melpaBuild,
  nix-update-script,
  stdenv,
  zig,
  emacs,
  xcbuild,
}:
let
  hashes = lib.importJSON ./hashes.json;
  pname = "ghostel";
  version = hashes.version;

  src = fetchFromGitHub {
    owner = "dakra";
    repo = "ghostel";
    rev = hashes.rev;
    hash = hashes.sourceHash;
  };

  deps = zig.fetchDeps {
    inherit src pname version;
    fetchAll = true;
    hash = hashes.zigDepsHash;
  };

  module = stdenv.mkDerivation {
    inherit
      pname
      version
      src
      deps
      ;

    nativeBuildInputs = [ zig ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ xcbuild ];

    env.EMACS_INCLUDE_DIR = "${emacs}/include";

    dontSetZigDefaultFlags = true;

    doCheck = true;

    zigBuildFlags = [
      "-Dcpu=baseline"
      # See https://github.com/ghostty-org/ghostty/blob/main/PACKAGING.md#build-options
      "-Doptimize=ReleaseFast"
    ];

    postConfigure = ''
      cp -rLT ${deps} "$ZIG_GLOBAL_CACHE_DIR/p"
      chmod -R u+w "$ZIG_GLOBAL_CACHE_DIR/p"
    '';

    strictDeps = true;

    __structuredAttrs = true;
  };

  libExt = stdenv.hostPlatform.extensions.sharedLibrary;
in
melpaBuild {
  inherit pname version src;

  files = ''
    (:defaults "etc" "ghostel-module${libExt}")
  '';

  preBuild = ''
    install ${module}/ghostel-module${libExt} ghostel-module${libExt}
    install --mode=444 ${module}/ghostel-module.version ghostel-module.version
  '';

  passthru = {
    # updateScript = nix-update-script { extraArgs = [ "--version=branch=main" ]; };
    updateScript = nix-update-script { };

    inherit module;
  };

  meta = {
    homepage = "https://github.com/dakra/ghostel";
    description = "Terminal emulator powered by libghostty";
    license = lib.licenses.gpl3Plus;
    changelog = "https://github.com/dakra/ghostel/releases/tag/v${version}";
  };
}
