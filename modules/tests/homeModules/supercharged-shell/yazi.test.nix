# Tests for flake.homeModules.supercharged-shell-yazi
# (neusis.supercharged-shell.tools.yazi). Enabled through the umbrella
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
            { neusis.supercharged-shell.tools.yazi = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [ self.homeModules.supercharged-shell ];
      };
    in
    {
      tests.hm-supercharged-shell-yazi = {
        test-enables-yazi-with-yy-wrapper-and-max-preview = {
          expr = {
            on = home.programs.yazi.enable;
            wrapper = home.programs.yazi.shellWrapperName;
            zsh = home.programs.yazi.enableZshIntegration;
            bash = home.programs.yazi.enableBashIntegration;
            hidden = home.programs.yazi.settings.mgr.show_hidden;
            previewMax = home.programs.yazi.settings.preview.max_width;
            keymap = map (k: k.run) home.programs.yazi.keymap.mgr.prepend_keymap;
            # plugins.<name> is a { package; settings; setup; } submodule
            plugin = baseNameOf (toString home.programs.yazi.plugins.max-preview.package);
            off = off.programs.yazi.enable;
            failed = t.failedAssertions home;
          };
          expected = {
            on = true;
            wrapper = "yy";
            zsh = true;
            bash = true;
            hidden = true;
            previewMax = 2000;
            keymap = [ "plugin max-preview" ];
            plugin = "yazi_img_max";
            off = false;
            failed = [ ];
          };
        };

        test-package-is-overridable = {
          expr = lib.getName (withTool { package = testPkgs.hello; }).programs.yazi.package;
          expected = "hello";
        };
      };
    };
}
