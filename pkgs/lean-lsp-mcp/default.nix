{
  lib,
  python3Packages,
  fetchFromGitHub,
  leanclient,
}:
let
  hashes = lib.importJSON ./hashes.json;
in
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "lean-lsp-mcp";
  version = hashes.version;
  pyproject = true;

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "oOo0oOo";
    repo = "lean-lsp-mcp";
    tag = "v${finalAttrs.version}";
    hash = hashes.sourceHash;
  };

  build-system = with python3Packages; [ setuptools ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "setuptools>=83.0.0" "setuptools"
  '';

  dependencies = [
    leanclient
    python3Packages.mcp
    python3Packages.orjson
    python3Packages.certifi
  ];

  pythonRelaxDeps = [
    "certifi"
    "mcp"
    "orjson"
  ];

  # Tests require a real Lean toolchain.
  doCheck = false;

  pythonImportsCheck = [ "lean_lsp_mcp" ];

  meta = {
    description = "MCP server for the Lean theorem prover via the Lean LSP";
    homepage = "https://github.com/oOo0oOo/lean-lsp-mcp";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ remix7531 ];
    mainProgram = "lean-lsp-mcp";
  };
})
