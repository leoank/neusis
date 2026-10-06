# Smoke tests for the harness itself: each evaluator comes up on its
# fixture base with no failing assertions.
{ self, ... }:
{
  perSystem =
    { testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      hm = t.evalHm {
        pkgs = testPkgs;
        modules = [ ];
      };
      darwin = t.evalDarwin { modules = [ ]; };
      nixos = t.evalNixos { modules = [ ]; };
    in
    {
      tests.harness = {
        test-hm-base-evaluates = {
          expr = {
            user = hm.home.username;
            stateVersion = hm.home.stateVersion;
            failed = t.failedAssertions hm;
          };
          expected = {
            user = "alice";
            stateVersion = "25.11";
            failed = [ ];
          };
        };

        test-hm-home-dir-matches-platform = {
          expr = hm.home.homeDirectory;
          expected = if testPkgs.stdenv.isDarwin then "/Users/alice" else "/home/alice";
        };

        test-darwin-base-evaluates = {
          expr = {
            host = darwin.networking.hostName;
            stateVersion = darwin.system.stateVersion;
            failed = t.failedAssertions darwin;
          };
          expected = {
            host = "fixture-darwin";
            stateVersion = 5;
            failed = [ ];
          };
        };

        test-nixos-base-evaluates = {
          expr = {
            host = nixos.networking.hostName;
            stateVersion = nixos.system.stateVersion;
            system = nixos.nixpkgs.hostPlatform.system;
            failed = t.failedAssertions nixos;
          };
          expected = {
            host = "fixture";
            stateVersion = "25.11";
            system = "x86_64-linux";
            failed = [ ];
          };
        };

        test-test-pkgs-have-overlays = {
          expr = testPkgs ? unstable && testPkgs ? inputs && testPkgs ? git-worktree-custom;
          expected = true;
        };

        test-pkg-helpers = {
          expr = {
            names = t.pkgNames [
              testPkgs.hello
              testPkgs.jq
              testPkgs.hello
            ];
            has = t.hasPkg "jq" [ testPkgs.jq ];
            hasNot = t.hasPkg "jq" [ testPkgs.hello ];
          };
          expected = {
            names = [
              "hello"
              "jq"
            ];
            has = true;
            hasNot = false;
          };
        };
      };
    };
}
