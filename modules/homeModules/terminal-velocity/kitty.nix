# terminal-velocity: kitty module.
# Enables `programs.kitty` with minimal chrome — no decorations
# (`titlebar-only` on Darwin since macOS requires *something* for
# native window controls; `yes` on Linux) and no inner borders.
# Extra shortcuts go through `keybindings`; none are set by default.
{ ... }:
{
  flake.homeModules.terminal-velocity-kitty =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.terminal-velocity.tools.kitty;
    in
    {
      options.neusis.terminal-velocity.tools.kitty = {
        enable = lib.mkEnableOption "kitty terminal emulator";

        extraSettings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          example = {
            font_size = 13;
            background_opacity = "0.95";
          };
          description = ''
            Additional `programs.kitty.settings` entries merged on
            top of the defaults (`hide_window_decorations`,
            `draw_minimal_borders`).
          '';
        };

        keybindings = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            "kitty_mod+space" = "select_tab";
          };
          description = ''
            Extra kitty `map` entries (key → action), passed to
            `programs.kitty.keybindings`. Empty by default, so kitty's
            own shortcuts are untouched.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.kitty = {
          enable = true;
          settings = {
            hide_window_decorations = if pkgs.stdenv.isDarwin then "titlebar-only" else "yes";
            draw_minimal_borders = "yes";
          }
          // cfg.extraSettings;
          inherit (cfg) keybindings;
        };
      };
    };
}
