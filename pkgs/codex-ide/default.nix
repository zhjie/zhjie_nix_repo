{
  lib,
  fetchFromGitHub,
  melpaBuild,
  transient,
}:

let
  hashes = lib.importJSON ./hashes.json;
in
melpaBuild {
  pname = "codex-ide";
  version = hashes.version;

  src = fetchFromGitHub {
    owner = "dgillis";
    repo = "emacs-codex-ide";
    rev = hashes.rev;
    hash = hashes.sourceHash;
  };

  packageRequires = [
    transient
  ];

  meta = {
    description = "Codex IDE for Emacs";
    homepage = "https://github.com/dgillis/emacs-codex-ide";
    license = lib.licenses.gpl3Plus;
  };
}
