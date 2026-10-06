# Tests for flake.homeModules.supercharged-shell-atuin
# (neusis.supercharged-shell.tools.atuin). Enabled through the umbrella
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
            { neusis.supercharged-shell.tools.atuin = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.supercharged-shell ];
      };
    in
    {
      tests.hm-supercharged-shell-atuin = {
        test-enables-atuin-daemon-and-zsh = {
          expr = {
            on = home.programs.atuin.enable;
            daemon = home.programs.atuin.daemon.enable;
            zsh = home.programs.atuin.enableZshIntegration;
            flags = home.programs.atuin.flags;
            sync = home.programs.atuin.settings.sync_frequency;
            off = off.programs.atuin.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            daemon = true;
            zsh = true;
            flags = [ "--disable-up-arrow" ];
            sync = "5m";
            off = false;
            failed = [ ];
          };
        };

        test-darwin-daemon-cleans-stale-socket = {
          expr =
            if testPkgs.stdenv.isDarwin then
              let
                args = home.launchd.agents.atuin-daemon.config.ProgramArguments;
              in
              builtins.length args == 1 && lib.hasPrefix builtins.storeDir (builtins.head args)
            else
              # not a Darwin home: nothing to check
              true;
          expected = true;
        };

        test-settings-replace-defaults = {
          expr =
            let
              s = (withTool { settings.auto_sync = false; }).programs.atuin.settings;
            in
            {
              autoSync = s.auto_sync;
              # neusis defaults are replaced wholesale …
              defaultsGone = !(s ? sync_frequency);
              # … while home-manager still merges in its daemon block
              daemon = s.daemon.enabled;
            };
          expected = {
            autoSync = false;
            defaultsGone = true;
            daemon = true;
          };
        };
      };
    };
}
