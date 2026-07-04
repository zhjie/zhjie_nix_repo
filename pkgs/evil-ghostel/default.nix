{
  lib,
  fetchFromGitHub,
  melpaBuild,
  evil,
  ghostel,
}:

let
  hashes = lib.importJSON ./hashes.json;
in
melpaBuild {
  pname = "evil-ghostel";
  version = hashes.version;

  src = fetchFromGitHub {
    owner = "dakra";
    repo = "ghostel";
    rev = hashes.rev;
    hash = hashes.sourceHash;
  };

  postPatch = ''
    cp extensions/evil-ghostel/evil-ghostel.el .
  '';

  files = ''
    ("evil-ghostel.el")
  '';

  packageRequires = [
    ghostel
    evil
  ];

  meta = {
    homepage = "https://github.com/dakra/ghostel";
    description = "Evil-mode integration for ghostel";
    license = lib.licenses.gpl3Plus;
  };
}
