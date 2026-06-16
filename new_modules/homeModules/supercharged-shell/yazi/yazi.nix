# supercharged-shell: yazi module.
# Enables `programs.yazi` (TUI file manager) with shell integration,
# hidden-file visibility, large image previews, and the bundled
# `max-preview` plugin (Tab `T` to maximize/restore the preview pane).
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
          keymap = {
            mgr.prepend_keymap = [
              {
                on = [ "T" ];
                run = "plugin max-preview";
                desc = "Maximize or restore preview";
              }
            ];
          };
          settings = {
            mgr.show_hidden = true;
            plugin.preloaders = [ ];
            preview = {
              max_width = 2000;
              max_height = 2000;
            };
          };
          plugins = {
            max-preview = ./yazi_img_max;
          };
        };
      };
    };
}
