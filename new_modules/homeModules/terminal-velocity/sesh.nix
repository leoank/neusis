# terminal-velocity: sesh module.
# `sesh` is a tmux session orchestrator — fuzzy-pick a session
# (existing or new from a project dir) and attach. Pairs with tmux,
# but the binary is useful standalone too (`sesh connect <name>`).
#
# `tmuxKey` only activates inside a tmux session — sets a binding
# under the prefix that opens the picker.
{ ... }:
{
  flake.homeModules.terminal-velocity-sesh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.terminal-velocity.tools.sesh;
    in
    {
      options.neusis.terminal-velocity.tools.sesh = {
        enable = lib.mkEnableOption "sesh tmux session manager";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.sesh;
          defaultText = lib.literalExpression "pkgs.sesh";
          example = lib.literalExpression "pkgs.unstable.sesh";
          description = ''
            The sesh package. The legacy config used
            `pkgs.unstable.sesh`; override here if you want the
            newer build (requires the `unstable` overlay).
          '';
        };

        tmuxKey = lib.mkOption {
          type = lib.types.str;
          default = "s";
          example = "S";
          description = ''
            tmux-prefix-keyed binding that opens the sesh picker.
            E.g. `s` ⇒ `prefix + s` opens the fuzzy session list.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.sesh = {
          enable = true;
          inherit (cfg) package tmuxKey;
        };
      };
    };
}
