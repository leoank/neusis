# Tests for flake.homeModules.terminal-velocity-kitty
# (neusis.terminal-velocity.tools.kitty), through the umbrella import.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;

      withTool =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.terminal-velocity
            { neusis.terminal-velocity.tools.kitty = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.terminal-velocity ];
      };
    in
    {
      tests.hm-terminal-velocity-kitty = {
        test-enables-kitty-with-platform-decorations = {
          expr = {
            on = home.programs.kitty.enable;
            decorations = home.programs.kitty.settings.hide_window_decorations;
            borders = home.programs.kitty.settings.draw_minimal_borders;
            off = off.programs.kitty.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            decorations = if testPkgs.stdenv.isDarwin then "titlebar-only" else "yes";
            borders = "yes";
            off = false;
            failed = [ ];
          };
        };

        test-extra-settings-merge-over-defaults = {
          expr =
            let
              s = (withTool { extraSettings = { font_size = 13; draw_minimal_borders = "no"; }; }).programs.kitty.settings;
            in
            {
              font = s.font_size;
              borders = s.draw_minimal_borders;
              keepsDecorations = s ? hide_window_decorations;
            };
          expected = {
            font = 13;
            borders = "no";
            keepsDecorations = true;
          };
        };
      };
    };
}
