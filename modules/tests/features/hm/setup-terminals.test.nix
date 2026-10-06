# Tests for flake.neusis.features.hm.setup-terminals: the legacy all-in-one
# terminal bundle.
#
# KNOWN BUG, pinned: the feature reads `./wezterm.lua`, `./gclb.py`,
# `./zellij.kdl` and `./zellij_layout.kdl` next to itself, but none of
# those files exist under modules/features/hm/ (they were not carried over
# in the port), so the feature does not evaluate. No machine uses it —
# ank's bundles use homeModules/terminal-velocity instead. Either move the
# files in or drop the feature; then replace this with real expectations.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      home = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.neusis.features.hm.setup-terminals ];
      };
    in
    {
      tests.feature-hm-setup-terminals = {
        test-does-not-evaluate-missing-bundled-files = {
          expr = home.programs.wezterm.extraConfig;
          expectedError = {
            type = "RestrictedPathError";
            msg = "wezterm.lua' does not exist";
          };
        };

        test-exported-hm-features = {
          expr = builtins.attrNames self.neusis.features.hm;
          expected = [
            "mac-app-util"
            "setup-terminals"
          ];
        };
      };
    };
}
