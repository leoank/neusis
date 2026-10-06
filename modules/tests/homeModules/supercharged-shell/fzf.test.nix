# Tests for flake.homeModules.supercharged-shell-fzf
# (neusis.supercharged-shell.tools.fzf). Enabled through the umbrella
# import but without the umbrella's own `enable` — tools are independent.
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
            self.homeModules.supercharged-shell
            { neusis.supercharged-shell.tools.fzf = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.supercharged-shell ];
      };
    in
    {
      tests.hm-supercharged-shell-fzf = {
        test-enables-fzf-with-bat-preview = {
          expr = {
            on = home.programs.fzf.enable;
            zsh = home.programs.fzf.enableZshIntegration;
            defaults = home.programs.fzf.defaultOptions;
            fileWidget = home.programs.fzf.fileWidgetOptions;
            off = off.programs.fzf.enable;
          };
          expected = {
            on = true;
            zsh = true;
            defaults = [ "--style full" ];
            fileWidget = [ "--preview='bat --color=always {}'" ];
            off = false;
          };
        };

        test-options-are-overridable = {
          expr = (withTool { defaultOptions = [ "--height 40%" ]; }).programs.fzf.defaultOptions;
          expected = [ "--height 40%" ];
        };
      };
    };
}
