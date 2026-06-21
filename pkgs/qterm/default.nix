{
  lib,
  fetchurl,
  cmake,
  qt6,
  stdenv,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "qterm";
  version = "0.8.2";

  src = fetchurl {
    url = "https://github.com/qterm/qterm/archive/refs/tags/${finalAttrs.version}.tar.gz";
    hash = "sha256-KuikJbL8Y8GRIpn5oacQ+Bpm0CuOlLHuVKaFHTlTxvI=";
  };

  nativeBuildInputs = [
    cmake
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qt5compat
    qt6.qtwayland
    qt6.qttools
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  meta = {
    description = "QTerm is a BBS client based on Qt";
    homepage = "https://github.com/qterm/qterm";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "qterm";
  };
})
