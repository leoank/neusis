# supercharged-shell: yazi module.
# Enables `programs.yazi` (TUI file manager) with shell integration,
# hidden-file visibility, large image previews, and the upstream
# `toggle-pane` plugin (`T` maximizes/restores the preview pane). It
# replaces a bundled `max-preview` plugin written for an older plugin
# API (`ya.app_emit`, deprecated in yazi 25.5).
{ ... }:
{
  flake.homeModules.supercharged-shell-yazi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell.tools.yazi;
    in
    {
      options.neusis.supercharged-shell.tools.yazi = {
        enable = lib.mkEnableOption "yazi TUI file manager";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.yazi;
          defaultText = lib.literalExpression "pkgs.yazi";
          description = "The yazi package.";
        };
      };

      config = lib.mkIf cfg.enable {
        programs.yazi = {
          enable = true;
          package = cfg.package;
          enableZshIntegration = true;
          enableBashIntegration = true;
          # HM 26.05 changed the default to "y"; keep the existing alias.
          shellWrapperName = "yy";
          keymap = {
            mgr.prepend_keymap = [
              {
                on = [ "T" ];
                run = "plugin toggle-pane max-preview";
                desc = "Maximize or restore preview";
              }
            ];
          };
          settings = {
            mgr.show_hidden = true;
            preview = {
              max_width = 2000;
              max_height = 2000;
            };
          };
          plugins = {
            toggle-pane = pkgs.yaziPlugins.toggle-pane;
          };
        };
      };
    };
}
