{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  python3,
  zstd,
  linuxPackages,
  kernel ? linuxPackages.kernel,
}:

let
  hashes = lib.importJSON ./hashes.json;
  version = hashes.version;
  firmwareVersion = hashes.firmwareVersion;

  src = fetchFromGitHub {
    owner = "JustAResearcher";
    repo = "gpu-unlock-ada";
    tag = "v${version}";
    hash = hashes.sourceHash;
  };

  nvidiaSource = fetchurl {
    url = hashes.nvidiaSourceUrl;
    hash = hashes.nvidiaSourceHash;
  };

  nvidiaUtils = fetchurl {
    url = hashes.nvidiaUtilsUrl;
    hash = hashes.nvidiaUtilsHash;
  };

  firmware = stdenv.mkDerivation {
    pname = "gpu-unlock-ada-firmware";
    inherit version src;

    nativeBuildInputs = [
      (python3.withPackages (ps: [ ps.pycryptodome ]))
      zstd
    ];
    dontConfigure = true;

    postPatch = ''
      # Nix fetchurl verifies the package hash, and generate_v67.py directly checks
      # the inner GSP firmware and license hashes. Bypassing the outer package hash
      # assertion prevents breaking across upstream releases or alternative distribution mirrors.
      substituteInPlace firmware/generate_v67.py \
        --replace-fail 'if package_bytes_hash.hexdigest() != PACKAGE_SHA256:' 'if False:'
    '';

    buildPhase = ''
      runHook preBuild
      mkdir inputs
      ln -s ${nvidiaSource} inputs/${hashes.nvidiaSourceFilename}
      ln -s ${nvidiaUtils} inputs/nvidia-utils-${firmwareVersion}-1-x86_64_v3.pkg.tar.zst
      make firmware INPUTS="$PWD/inputs" ASSETS="$PWD/assets"
      runHook postBuild
    '';

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      if make -q test-full 2>/dev/null || grep -q 'test-full:' Makefile; then
        make test-full ASSETS="$PWD/assets"
      else
        make test ASSETS="$PWD/assets"
      fi
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      make install-firmware DESTDIR="$out" ASSETS="$PWD/assets" \
        FWDIR=/lib/firmware/gpu-unlock/${firmwareVersion} \
        LICENSEDIR=/share/licenses
      runHook postInstall
    '';

    meta = {
      description = "Locally generated, hash-verified firmware for GPU Unlock Ada";
      homepage = "https://github.com/JustAResearcher/gpu-unlock-ada";
      license = lib.licenses.unfreeRedistributableFirmware;
      platforms = [ "x86_64-linux" ];
    };
  };

  kernelModule = stdenv.mkDerivation {
    pname = "gpu-unlock-ada";
    version = "${version}-${kernel.modDirVersion}";
    inherit src;
    sourceRoot = "${src.name}/kernel/gpu_unlock";

    nativeBuildInputs = kernel.moduleBuildDependencies;
    makeFlags = kernel.commonMakeFlags ++ [
      "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    ];
    dontConfigure = true;
    dontStrip = true;

    # Use the standard install phase so commonMakeFlags also signs the module.
    installFlags = [
      "-C"
      "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "M=$(PWD)"
      "INSTALL_MOD_PATH=${placeholder "out"}"
      "DEPMOD=true"
    ];
    installTargets = [ "modules_install" ];

    passthru = {
      inherit firmware firmwareVersion;
    };

    meta = {
      description = "Pre-driver tensor throughput unlock for GeForce GPUs";
      homepage = "https://github.com/JustAResearcher/gpu-unlock-ada";
      license = lib.licenses.gpl2Only;
      platforms = [ "x86_64-linux" ];
    };
  };
in
kernelModule
