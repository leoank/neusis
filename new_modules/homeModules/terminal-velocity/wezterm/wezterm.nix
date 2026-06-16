# terminal-velocity: wezterm module.
# Enables `programs.wezterm` and feeds it the bundled `wezterm.lua`.
# Zsh integration off — wezterm's shell integration is opinionated
# and most setups don't need it.
{ ... }:
{
  flake.homeModules.terminal-velocity-wezterm =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.terminal-velocity.tools.wezterm;
    in
    {
      options.neusis.terminal-velocity.tools.wezterm = {
        enable = lib.mkEnableOption "wezterm terminal emulator";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.wezterm;
          defaultText = lib.literalExpression "pkgs.wezterm";
          description = "The wezterm package.";
        };

        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = builtins.readFile ./wezterm.lua;
          defaultText = lib.literalExpression "builtins.readFile ./wezterm.lua";
          description = ''
            Lua config appended to wezterm's runtime config. Defaults
            to the bundled `wezterm.lua` next to this module.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.wezterm = {
          enable = true;
          inherit (cfg) package extraConfig;
          enableZshIntegration = false;
        };
      };
    };
}
