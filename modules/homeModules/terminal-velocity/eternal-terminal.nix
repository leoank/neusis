# terminal-velocity: eternal-terminal (et) module.
# Installs `et` — TCP-based SSH replacement that survives network
# blips and preserves your tmux/scrollback across reconnects. Like
# mosh but plays nicer through corporate firewalls (TCP/2022 by
# default, no UDP).
#
#   et user@host
#
# As with mosh, server-side install is out of scope; this module
# only sets up the client.
{ ... }:
{
  flake.homeModules.terminal-velocity-eternal-terminal =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.terminal-velocity.tools.eternal-terminal;
    in
    {
      options.neusis.terminal-velocity.tools.eternal-terminal = {
        enable = lib.mkEnableOption "Eternal Terminal (`et`) client";
      };

      config = lib.mkIf cfg.enable {
        home.packages = [ pkgs.eternal-terminal ];
      };
    };
}
