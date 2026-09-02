{
  description = "zhjie's personal nix packages";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
            pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [
              "roon-server"
              "antigravity-acp"
            ];
        };
      in
      {
        packages = rec {
          emacs-plus = pkgs.callPackage ./pkgs/emacs-plus { };
          emacs-client = pkgs.callPackage ./pkgs/emacs-client { };
          ghostel = pkgs.emacsPackages.callPackage ./pkgs/ghostel { };
          docx = pkgs.callPackage ./pkgs/docx { };
          leanclient = pkgs.callPackage ./pkgs/leanclient { };
          mcp = pkgs.callPackage ./pkgs/mcp { };
          lean-lsp-mcp = pkgs.callPackage ./pkgs/lean-lsp-mcp { inherit leanclient mcp; };
          pi-acp = pkgs.callPackage ./pkgs/pi-acp { };
          antigravity-acp = pkgs.callPackage ./pkgs/antigravity-acp { };
          pptxgenjs = pkgs.callPackage ./pkgs/pptxgenjs { };
        }
        // (
          if system == "x86_64-linux" then
            {
              qterm = pkgs.callPackage ./pkgs/qterm { };
              roon-server = pkgs.callPackage ./pkgs/roonserver { };
            }
          else
            { }
        );
      }
    );
}
