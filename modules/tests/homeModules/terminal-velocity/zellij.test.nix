# Tests for flake.homeModules.terminal-velocity-zellij
# (neusis.terminal-velocity.tools.zellij), through the umbrella import.
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
            { neusis.terminal-velocity.tools.zellij = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.terminal-velocity ];
      };
    in
    {
      tests.hm-terminal-velocity-zellij = {
        test-enables-zellij-with-bundled-kdl-files = {
          expr = {
            on = home.programs.zellij.enable;
            theme = home.programs.zellij.settings.theme;
            mode = home.programs.zellij.settings.default_mode;
            zsh = home.programs.zellij.enableZshIntegration;
            config = baseNameOf (toString home.xdg.configFile."zellij/config.kdl".source);
            layout = baseNameOf (toString home.xdg.configFile."zellij/layouts/default.kdl".source);
            off = off.programs.zellij.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            theme = "gruvbox-dark";
            mode = "locked";
            zsh = false;
            config = "config.kdl";
            layout = "layout.kdl";
            off = false;
            failed = [ ];
          };
        };

        test-null-paths-skip-the-files = {
          expr =
            let
              cfg = withTool {
                configFile = null;
                defaultLayout = null;
                settings = { };
              };
            in
            {
              config = cfg.xdg.configFile ? "zellij/config.kdl";
              layout = cfg.xdg.configFile ? "zellij/layouts/default.kdl";
            };
          expected = {
            config = false;
            layout = false;
          };
        };
      };
    };
}
