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
              "gpu-unlock-ada-firmware"
            ];
        };
      in
      {
        packages = rec {
          emacs-plus = pkgs.callPackage ./pkgs/emacs-plus { };
          emacs-client = pkgs.callPackage ./pkgs/emacs-client { };
          leanclient = pkgs.callPackage ./pkgs/leanclient { };
          lean-lsp-mcp = pkgs.callPackage ./pkgs/lean-lsp-mcp { inherit leanclient mcp; };
          mcp = pkgs.callPackage ./pkgs/mcp { };
        }
        // (
          if system == "x86_64-linux" then
            {
              qterm = pkgs.callPackage ./pkgs/qterm { };
              roon-server = pkgs.callPackage ./pkgs/roonserver { };
              gnomeExtensions.keyd = pkgs.callPackage ./pkgs/gnome-shell-extension-keyd { };
              gpu-unlock-ada = pkgs.callPackage ./pkgs/gpu-unlock-ada { };
              gpu-unlock-ada-firmware = (pkgs.callPackage ./pkgs/gpu-unlock-ada { }).firmware;
            }
          else
            { }
        );
      }
    )
    // {
      nixosModules = {
        gpu-unlock-ada = import ./modules/gpu-unlock-ada.nix;
        default = self.nixosModules.gpu-unlock-ada;
      };
    };
}
