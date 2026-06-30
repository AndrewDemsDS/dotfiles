{
  description = "AndrewDems dotfiles — Hyprland/Quickshell (ii) desktop. Home-manager module + dev shell.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # (Quickshell now comes from plain nixpkgs 0.3.0 — the old pinned-source input was for the
    # 0.2.1-era override and is no longer needed; see nix/home-module.nix and docs/13.)
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      deps = import ./setup/dependencies.nix;
    in {
      # ii desktop runtime deps + activation. Import from a NixOS/home-manager config:
      #   imports = [ inputs.dotfiles.homeManagerModules.default ];
      # Provides packages/dconf/venv ONLY — the dotfiles stay the live ~/.config git checkout
      # (preserves Quickshell hot-reload); Nix does not place hypr/quickshell files.
      homeManagerModules.default = import ./nix/home-module.nix;

      # `nix develop` — the lint/test toolchain (cross-distro; on NixOS the runtime comes from
      # the home module above). `just lint` needs qmllint (qt6.qtdeclarative).
      devShells.${system}.default = pkgs.mkShell {
        packages = (map (n: pkgs.${n}) (deps.core ++ deps.optional))
          ++ [ pkgs.just pkgs.qt6.qtdeclarative ];
      };
    };
}
