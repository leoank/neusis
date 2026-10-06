# Tests for flake.homeModules.terminal-velocity (umbrella): imports every
# terminal/multiplexer tool sub-module, all off by default.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      home = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.terminal-velocity ];
      };
    in
    {
      tests.hm-terminal-velocity = {
        test-all-tools-declared-and-off-by-default = {
          expr = lib.mapAttrs (_: tool: tool.enable) home.neusis.terminal-velocity.tools;
          expected = lib.genAttrs [
            "eternal-terminal"
            "kitty"
            "mosh"
            "sesh"
            "tmux"
            "wezterm"
            "zellij"
          ] (_: false);
        };

        test-import-alone-configures-no-terminal = {
          expr = lib.mapAttrs (_: p: p.enable) {
            inherit (home.programs)
              kitty
              wezterm
              tmux
              zellij
              ;
          };
          expected = {
            kitty = false;
            wezterm = false;
            tmux = false;
            zellij = false;
          };
        };
      };
    };
}
