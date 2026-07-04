{
  description = "zhjie's personal nix packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
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
          emacs-plus = pkgs.callPackage ./pkgs/emacs-plus { };
          emacs-plus-31 = pkgs.callPackage ./pkgs/emacs-plus-31 { };
          emacs-client = pkgs.callPackage ./pkgs/emacs-client { };
          claude-code-ide = pkgs.emacsPackages.callPackage ./pkgs/claude-code-ide { };
          codex-ide = pkgs.emacsPackages.callPackage ./pkgs/codex-ide { };
          ghostel = pkgs.emacsPackages.callPackage ./pkgs/ghostel { };
          evil-ghostel = pkgs.emacsPackages.callPackage ./pkgs/evil-ghostel { inherit ghostel; };
          docx = pkgs.callPackage ./pkgs/docx { };
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
