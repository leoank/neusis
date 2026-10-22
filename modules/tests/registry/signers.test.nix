# Pins anklab's trusted commit signers (modules/registry/signers/anklab.nix):
# ank's signing key, read from his public key file without its comment.
{ self, ... }:
{
  perSystem =
    { ... }:
    {
      tests.registry-signers = {
        test-anklab-signers = {
          expr = self.neusis.lib.autoUpdate.allowedSigners self.neusis.registry.signers.anklab;
          expected = ''
            ank@leoank.me namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH40XzfXPtcTwJ8FHxHXCaEteylFOwtuw5TaY5CZ5NS
          '';
        };
      };
    };
}
