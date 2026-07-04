{
  lib,
  fetchFromGitHub,
  melpaBuild,
  transient,
  web-server,
  websocket,
}:

let
  hashes = lib.importJSON ./hashes.json;
in
melpaBuild {
  pname = "claude-code-ide";
  version = hashes.version;

  src = fetchFromGitHub {
    owner = "manzaltu";
    repo = "claude-code-ide.el";
    rev = hashes.rev;
    hash = hashes.sourceHash;
  };

  packageRequires = [
    transient
    web-server
    websocket
  ];

  meta = {
    description = "Claude Code IDE for Emacs";
    homepage = "https://github.com/manzaltu/claude-code-ide.el";
    license = lib.licenses.gpl3Plus;
  };
}
