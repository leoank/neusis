# terminal-velocity: mosh module.
# Installs `mosh` (mobile shell) — UDP-based SSH replacement that
# survives roaming networks, sleep/wake cycles, and lousy latency.
# Use as a drop-in for `ssh` against any host that also has mosh
# server installed:
#
#   mosh user@host
#
# Server-side install is out of scope here; this module only sets
# up the client.
{ ... }:
{
  flake.homeModules.terminal-velocity-mosh =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.terminal-velocity.tools.mosh;
    in
    {
      options.neusis.terminal-velocity.tools.mosh = {
        enable = lib.mkEnableOption "mosh (mobile shell) client";
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.mosh ];
      };
    };
}
