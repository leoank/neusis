# supercharged-shell: atuin module.
# Encrypted, syncable shell history. Uses atuin.sh as the default
# sync backend (free tier) — set `sync.address` to a self-hosted
# instance if you're running your own.
#
# Note: in the legacy `homes/common/dev/terminals.nix`, atuin was
# gated to Darwin only (`atuin_enable = if pkgs.stdenv.isDarwin then
# true else false`). Here it's cross-platform by default; flip
# `enable` off per host if some Linux box doesn't want it.
{ ... }:
{
  flake.homeModules.supercharged-shell-atuin =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell.tools.atuin;
    in
    {
      options.neusis.supercharged-shell.tools.atuin = {
        enable = lib.mkEnableOption "atuin shell history";

        flags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "--disable-up-arrow" ];
          description = ''
            CLI flags injected into the zsh integration. The default
            disables the up-arrow rebind so vanilla zsh history-up
            still works; atuin still owns `Ctrl-R`.
          '';
        };

        settings = lib.mkOption {
          type = lib.types.attrs;
          default = {
            auto_sync = true;
            sync_frequency = "5m";
            sync_address = "https://api.atuin.sh";
            search_mode = "fuzzy";
            enter_accept = false;
          };
          description = ''
            Contents of `~/.config/atuin/config.toml`. Defaults sync
            every 5 minutes against the public atuin server; point
            `sync_address` at your self-host if you have one.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        programs.atuin = {
          enable = true;
          daemon.enable = true;
          inherit (cfg) flags settings;
          enableZshIntegration = true;
        };
      };
    };
}
