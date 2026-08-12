# neusis — the fleet-management CLI.
#
# Flake-parts module exposing `flake.packages.<system>.neusis`, built
# from the Go sources under ../../../cli with buildGoModule. Enables
# `nix run github:leoank/neusis#neusis`.
#
# After changing cli/go.mod or cli/go.sum, update `vendorHash`:
# set it to lib.fakeHash, build, and copy the expected hash from the
# error.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.neusis = pkgs.buildGoModule {
        pname = "neusis";
        version = "0.1.0";
        src = ../../../cli;
        vendorHash = "sha256-oVSN372HPLva84f+OdptJiUeKhE7EigbCJJfpnOnCnA=";
        ldflags = [
          "-s"
          "-w"
          "-X"
          "github.com/leoank/neusis/cli/cmd.version=0.1.0"
        ];
        # The Go module is `.../cli`, so the built binary is `cli`;
        # rename it to the command name users expect.
        postInstall = ''
          mv "$out/bin/cli" "$out/bin/neusis"
        '';
        meta = {
          description = "Scaffold and grow a neusis NixOS/nix-darwin fleet repository";
          mainProgram = "neusis";
        };
      };
    };
}
