# neusis-promote — moves the deploy/<group> branches (docs/auto-update-spec.md
# §4.3).
#
# Flake-parts module that exposes `flake.packages.<system>.neusis-promote`.
# CI's promote workflow runs it (`nix run .#neusis-promote`); the rules
# and its interface are in the header of neusis-promote.sh.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.neusis-promote = pkgs.writeShellApplication {
        name = "neusis-promote";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.git
          pkgs.jq
          pkgs.openssh
        ];
        text = builtins.readFile ./neusis-promote.sh;
      };
    };
}
