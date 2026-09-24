{
  lib,
  stdenv,
  zerotierone,
}:

zerotierone.overrideAttrs (oldAttrs: {
  postInstall =
    (oldAttrs.postInstall or "")
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      cp MacEthernetTapAgent $out/bin/MacEthernetTapAgent
    '';
})
