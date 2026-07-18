{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

let
  hashes = lib.importJSON ./hashes.json;
in
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "leanclient";
  version = hashes.version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "oOo0oOo";
    repo = "leanclient";
    tag = "v${finalAttrs.version}";
    hash = hashes.sourceHash;
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    orjson
    psutil
    tqdm
  ];

  # Tests require a real Lean toolchain.
  doCheck = false;

  pythonImportsCheck = [ "leanclient" ];

  meta = {
    description = "Python client for the Lean theorem prover LSP";
    homepage = "https://github.com/oOo0oOo/leanclient";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ remix7531 ];
  };
})
