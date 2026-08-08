{
  description = "zhjie's personal nix packages";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
            ];
        };
      in
      {
        packages = rec {
          arrow-cpp = pkgs.callPackage ./pkgs/arrow-cpp { };
          emacs-plus = pkgs.callPackage ./pkgs/emacs-plus { };
          emacs-plus-31 = pkgs.callPackage ./pkgs/emacs-plus-31 { };
          emacs-client = pkgs.callPackage ./pkgs/emacs-client { };
          ghostel = pkgs.emacsPackages.callPackage ./pkgs/ghostel { };
          docx = pkgs.callPackage ./pkgs/docx { };
          leanclient = pkgs.callPackage ./pkgs/leanclient { };
          lean-lsp-mcp = pkgs.callPackage ./pkgs/lean-lsp-mcp { inherit leanclient; };
          pi-acp = pkgs.callPackage ./pkgs/pi-acp { };
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
