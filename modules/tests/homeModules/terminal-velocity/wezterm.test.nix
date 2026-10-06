# Tests for flake.homeModules.terminal-velocity-wezterm
# (neusis.terminal-velocity.tools.wezterm), through the umbrella import.
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
            { neusis.terminal-velocity.tools.wezterm = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.terminal-velocity ];
      };
    in
    {
      tests.hm-terminal-velocity-wezterm = {
        test-enables-wezterm-with-bundled-lua = {
          expr = {
            on = home.programs.wezterm.enable;
            pkg = lib.getName home.programs.wezterm.package;
            zsh = home.programs.wezterm.enableZshIntegration;
            bundledLua =
              home.programs.wezterm.extraConfig
              == builtins.readFile ../../../homeModules/terminal-velocity/wezterm/wezterm.lua;
            off = off.programs.wezterm.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            pkg = "wezterm";
            zsh = false;
            bundledLua = true;
            off = false;
            failed = [ ];
          };
        };

        test-extra-config-is-replaceable = {
          expr = (withTool { extraConfig = "return {}"; }).programs.wezterm.extraConfig;
          expected = "return {}";
        };
      };
    };
}
