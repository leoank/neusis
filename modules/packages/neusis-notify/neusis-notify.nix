# neusis-notify — one alert to ntfy and by email (Postmark API).
#
# Flake-parts module that exposes `flake.packages.<system>.neusis-notify`.
# Shared by CI (`nix run .#neusis-notify`) and the auto-update hook on
# hosts (docs/auto-update-spec.md §6.4). Channels come from the
# environment or `--env-file`; see the header of neusis-notify.sh.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.neusis-notify = pkgs.writeShellApplication {
        name = "neusis-notify";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
        ];
        text = builtins.readFile ./neusis-notify.sh;
      };
    };
}
