# Tests for flake.homeModules.supercharged-shell (umbrella): the curated
# CLI/dev-tool bundle, extraPackages, and that every tool sub-module is
# declared but off by default.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;

      shellHome =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.supercharged-shell
            extra
          ];
        };

      home = shellHome { neusis.supercharged-shell.enable = true; };
      names = t.pkgNames home.home.packages;
    in
    {
      tests.hm-supercharged-shell = {
        test-enable-installs-curated-bundle = {
          expr = {
            core = lib.all (n: builtins.elem n names) [
              "bat"
              "eza"
              "fd"
              "ripgrep"
              "htop"
              "comma"
              "nix-output-monitor"
              "cargo"
              "python3"
              "lua"
            ];
            # sioyek is Linux-only in the bundle
            sioyek = builtins.elem "sioyek" names;
            failed = t.failedAssertions home;
          };
          expected = {
            core = true;
            sioyek = !testPkgs.stdenv.isDarwin;
            failed = [ ];
          };
        };

        test-extra-packages-are-appended = {
          expr =
            let
              cfg = shellHome {
                neusis.supercharged-shell = {
                  enable = true;
                  extraPackages = [ testPkgs.jq ];
                };
              };
            in
            t.hasPkg "jq" cfg.home.packages && t.hasPkg "bat" cfg.home.packages;
          expected = true;
        };

        test-all-tools-declared-and-off-by-default = {
          expr = lib.mapAttrs (_: tool: tool.enable) home.neusis.supercharged-shell.tools;
          expected = lib.genAttrs [
            "atuin"
            "direnv"
            "fzf"
            "nix-init"
            "nix-search-tv"
            "nix-your-shell"
            "television"
            "yazi"
            "zoxide"
          ] (_: false);
        };

        test-disabled-installs-nothing-from-the-bundle = {
          # home-manager always adds its own few packages (session vars,
          # man-db, manpage); none of the bundle must be there.
          expr = lib.any (n: builtins.elem n [ "bat" "eza" "ripgrep" "cargo" ]) (t.pkgNames (shellHome { }).home.packages);
          expected = false;
        };
      };
    };
}
