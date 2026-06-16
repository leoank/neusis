# supercharged-shell: television (tv) module.
# Enables `programs.television` — a modern, channel-based fuzzy
# picker. Defaults to the stable nixpkgs build; flip to
# `pkgs.unstable.television` via the `package` option if you want
# the latest features.
{ ... }:
{
  flake.homeModules.supercharged-shell-television =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell.tools.television;
    in
    {
      options.neusis.supercharged-shell.tools.television = {
        enable = lib.mkEnableOption "television fuzzy picker";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.television;
          defaultText = lib.literalExpression "pkgs.television";
          example = lib.literalExpression "pkgs.unstable.television";
          description = ''
            The television package. Override to use the unstable
            build (`pkgs.unstable.television`) — requires the
            `unstable` overlay to be active.
          '';
        };

        enableZshIntegration = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Replace Ctrl-R / Ctrl-T zsh bindings with tv's. Off by
            default because fzf (`tools.fzf`) wants the same keys —
            pick one. Turn this on if you don't enable fzf.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.television = {
          enable = true;
          inherit (cfg) package enableZshIntegration;
        };
      };
    };
}
