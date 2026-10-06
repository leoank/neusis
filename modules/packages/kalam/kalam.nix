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
    { pkgs, lib, ... }:
    {
      # kalam-py pulls in Wayland (badPlatforms darwin) and cannot even
      # evaluate there; drop it on Darwin so `nix flake check` can pass.
      packages =
        lib.filterAttrs (name: _: !(pkgs.stdenv.isDarwin && name == "kalam-py"))
          (self.neusis.lib.kalam.mkKalamVariants {
            pkgs = pkgs.extend self.outputs.overlays.git-worktree;
            inherit (self) inputs outputs;
            root = ./_flavors;
          });
    };
}
