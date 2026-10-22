# Trusted commit signers for anklab (docs/auto-update-spec.md §5).
#
# Hosts deploy, and CI promotes, only commits whose head is signed by one
# of these keys. A host checks against the list in the config it is
# running, so changing this list takes a commit signed by a key already
# on it. The CI bot's key joins here once it exists (milestone M5).
{ lib, ... }:
let
  # `<type> <base64>` of a public key file, without its comment.
  keyOf = file: lib.concatStringsSep " " (lib.take 2 (lib.splitString " " (lib.fileContents file)));
in
{
  flake.neusis.registry.signers.anklab = [
    {
      principal = "ank@leoank.me";
      # the key supercharged-git signs with (~/.ssh/id_ed25519)
      key = keyOf ../../users/ank/id_ed25519.pub;
    }
  ];
}
