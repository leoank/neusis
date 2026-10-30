# neusis-switch-check — refuses a manual switch to a commit comin would
# replace (docs/auto-update-spec.md §9.5).
#
# Flake-parts module that exposes `flake.packages.<system>.neusis-switch-check`.
# `agnosticModules.auto-update` runs it before activation (a NixOS
# pre-switch check, a darwin preActivation step); the rules are in the
# header of neusis-switch-check.sh.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.neusis-switch-check = pkgs.writeShellApplication {
        name = "neusis-switch-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
        ];
        text = builtins.readFile ./neusis-switch-check.sh;
      };
    };
}
