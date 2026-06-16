# terminal-velocity: zellij module.
# Enables `programs.zellij` with the gruvbox-dark theme, simplified
# UI, and `locked` default mode (Zellij's keymaps don't grab your
# prefix until you unlock with Ctrl-g). Also writes the bundled
# `config.kdl` and `layout.kdl` to `~/.config/zellij/`.
{ ... }:
{
  flake.homeModules.terminal-velocity-zellij =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.terminal-velocity.tools.zellij;
    in
    {
      options.neusis.terminal-velocity.tools.zellij = {
        enable = lib.mkEnableOption "zellij terminal multiplexer";

        configFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = ./config.kdl;
          defaultText = lib.literalExpression "./config.kdl";
          description = ''
            Path to a `config.kdl` for `~/.config/zellij/config.kdl`.
            Set `null` to skip writing a config file (lets you manage
            it elsewhere).
          '';
        };

        defaultLayout = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = ./layout.kdl;
          defaultText = lib.literalExpression "./layout.kdl";
          description = ''
            Path to a layout file written to
            `~/.config/zellij/layouts/default.kdl`. Set `null` to
            skip.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = {
            theme = "gruvbox-dark";
            simplified_ui = true;
            default_mode = "locked";
          };
          description = ''
            `programs.zellij.settings` (rendered into the yaml/kdl
            config zellij reads at startup).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.zellij = {
          enable = true;
          inherit (cfg) settings;
          enableZshIntegration = false;
        };

        xdg.configFile = lib.mkMerge [
          (lib.mkIf (cfg.configFile != null) {
            "zellij/config.kdl".source = cfg.configFile;
          })
          (lib.mkIf (cfg.defaultLayout != null) {
            "zellij/layouts/default.kdl".source = cfg.defaultLayout;
          })
        ];
      };
    };
}
