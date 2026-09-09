{
  lib,
  stdenv,
  coreutils,
  procps,
  keyd,
}:

stdenv.mkDerivation {
  pname = "gnome-shell-extension-keyd";
  version = keyd.version;

  src = "${keyd}/share/keyd/gnome-extension-45";

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    local target="$out/share/gnome-shell/extensions/keyd@keyd.rvaiya.github.com"
    mkdir -p "$target"
    cp -r ./* "$target/"
    substituteInPlace "$target/metadata.json" \
      --replace-fail '"49"' '"49", "50", "51"'
    substituteInPlace "$target/extension.js" \
      --replace-fail "'mkfifo '" "'${coreutils}/bin/mkfifo '" \
      --replace-fail "'keyd-application-mapper -d'" "'${keyd}/bin/keyd-application-mapper -d'" \
      --replace-fail "'pkill -f keyd-application-mapper'" "'${procps}/bin/pkill -f keyd-application-mapper'"
    runHook postInstall
  '';

  passthru.extensionUuid = "keyd@keyd.rvaiya.github.com";

  meta = {
    description = "GNOME Shell extension for keyd application mapper";
    homepage = "https://github.com/rvaiya/keyd";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
