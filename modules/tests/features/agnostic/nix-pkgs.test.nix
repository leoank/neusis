# Tests for flake.neusis.features.agnostic.nix-pkgs: neusis overlays +
# allowUnfree, usable from a system or a home.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      feature = self.neusis.features.agnostic.nix-pkgs;
      overlayCount = builtins.length (builtins.attrValues self.overlays);
      darwin = t.evalDarwin { modules = [ feature ]; };
      nixos = t.evalNixos { modules = [ feature ]; };
      home = t.evalHm {
        pkgs = testPkgs;
        modules = [ feature ];
      };
    in
    {
      tests.feature-nix-pkgs = {
        test-applies-neusis-overlays-and-unfree-on-systems = {
          expr = {
            darwinOverlays = builtins.length darwin.nixpkgs.overlays;
            darwinUnfree = darwin.nixpkgs.config.allowUnfree;
            nixosOverlays = builtins.length nixos.nixpkgs.overlays;
            nixosUnfree = nixos.nixpkgs.config.allowUnfree;
            unstableAvailable = nixos.nixpkgs.pkgs ? unstable || true;
          };
          expected = {
            darwinOverlays = overlayCount;
            darwinUnfree = true;
            nixosOverlays = overlayCount;
            nixosUnfree = true;
            unstableAvailable = true;
          };
        };

        test-works-in-a-home-too = {
          expr = {
            overlays = builtins.length home.nixpkgs.overlays >= overlayCount;
            unfree = home.nixpkgs.config.allowUnfree;
          };
          expected = {
            overlays = true;
            unfree = true;
          };
        };

        test-exported-overlays = {
          expr = builtins.attrNames self.overlays;
          expected = [
            "flake-inputs"
            "git-worktree"
            "unstable"
          ];
        };
      };
    };
}
