# Publishes every kalam flavor under `./_flavors/<name>` as a perSystem
# package via `flake.neusis.lib.kalam.mkKalamVariants`. Subdir `base`
# becomes `kalam`; any other `<name>` becomes `kalam-<name>`.
#
# `git-worktree` overlay is applied via `pkgs.extend` because some
# flavor config modules reference `pkgs.git-worktree-custom` (see
# `_flavors/*/config/plugins/git/git-worktree.nix`). All other build
# inputs come from the perSystem `pkgs` configured in
# `modules/system-pkgs.nix` — no per-package nixpkgs rebuild.
{ self, ... }:
{
  flake-file.inputs.nixvim = {
    url = "github:nix-community/nixvim/nixos-26.05";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  perSystem =
    { pkgs, ... }:
    let
      variants = self.neusis.lib.kalam.mkKalamVariants {
        pkgs = pkgs.extend self.outputs.overlays.git-worktree;
        inherit (self) inputs outputs;
        root = ./_flavors;
      };

      # kalam-zero as a standalone init.lua for machines without Nix
      # (ADR-0016): the same config with nixvim's wrapper assumptions
      # removed. RUN-20261103-g9nmnp found these options sufficient; the
      # build fails if the file still names the Nix store.
      zeroInit =
        (variants.kalam-zero.extend {
          wrapRc = false;
          impureRtp = true;
          luaLoader.enable = null;
        }).config.build.initFile;
    in
    {
      packages = variants // {
        kalam-zero-init = pkgs.runCommand "kalam-zero-init" { } ''
          if grep -n /nix/store ${zeroInit}; then
            echo "kalam-zero-init: init.lua references the Nix store" >&2
            exit 1
          fi
          install -Dm644 ${zeroInit} $out/init.lua
        '';
      };
    };
}
