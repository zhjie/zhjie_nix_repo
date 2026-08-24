{
  lib,
  stdenv,
  python3Packages,
  fetchFromGitHub,
}:

let
  hashes = lib.importJSON ./hashes.json;

  src = fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "python-sdk";
    tag = "v${hashes.version}";
    hash = hashes.sourceHash;
  };

  mcp-types = python3Packages.buildPythonPackage {
    pname = "mcp-types";
    version = hashes.version;
    pyproject = true;
    inherit src;
    sourceRoot = "source/src/mcp-types";

    build-system = with python3Packages; [
      hatchling
      uv-dynamic-versioning
    ];

    dependencies = with python3Packages; [
      pydantic
      typing-extensions
    ];

    doCheck = false;
    pythonImportsCheck = [ "mcp_types" ];
  };
in
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "mcp";
  version = hashes.version;
  pyproject = true;
  inherit src;

  postPatch = lib.optionalString stdenv.buildPlatform.isDarwin ''
    if [ -f tests/client/test_stdio.py ]; then
      substituteInPlace tests/client/test_stdio.py \
        --replace-warn "time.sleep(0.1)" "time.sleep(1)"
    fi
  '';

  build-system = with python3Packages; [
    hatchling
    uv-dynamic-versioning
  ];

  dependencies = with python3Packages; [
    anyio
    httpx
    httpx-sse
    httpx2
    jsonschema
    mcp-types
    opentelemetry-api
    pydantic
    pydantic-settings
    pyjwt
    python-multipart
    sse-starlette
    starlette
    typing-extensions
    typing-inspection
    uvicorn
  ];

  optional-dependencies = with python3Packages; {
    cli = [
      python-dotenv
      typer
    ];
    rich = [
      rich
    ];
    ws = [
      websockets
    ];
  };

  doCheck = false;
  pythonImportsCheck = [ "mcp" ];

  meta = {
    changelog = "https://github.com/modelcontextprotocol/python-sdk/releases/tag/v${finalAttrs.version}";
    description = "Official Python SDK for Model Context Protocol servers and clients";
    homepage = "https://github.com/modelcontextprotocol/python-sdk";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
})
