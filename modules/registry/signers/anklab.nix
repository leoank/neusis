# Trusted commit signers for anklab (docs/auto-update-spec.md §5).
#
# Hosts deploy, and CI promotes, only commits whose head is signed by one
# of these keys. A host checks against the list in the config it is
# running, so changing this list takes a commit signed by a key already
# on it. `git verify-commit` matches the principal against the committer
# email, so each principal is the address its commits are made with.
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
    {
      # The GitHub App "Neusis auto updates ci bot" commits lock bumps as
      # neusis-auto-updates-ci-bot[bot] (user id 349938074), signed with
      # the BOT_SIGNING_KEY secret (docs/github-bot-setup.md).
      principal = "349938074+neusis-auto-updates-ci-bot[bot]@users.noreply.github.com";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFLdFoEW0iv7jNftCkoEUdJR5nujWkLjpu+WqZg5UZ6B";
    }
  ];
}
