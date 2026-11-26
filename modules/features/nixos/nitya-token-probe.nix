# Neusis feature: nitya's token probe (nitya EXP-20261123-bhfz49), wired for ank's
# fleet (NixOS).
#
# The probe and its service come from the nitya flake (`nixosModules.token-probe`).
# Every 6 hours it refreshes ank's nitya provider tokens, reads a little with each and
# appends one JSON line per check to /var/lib/nitya-token-probe/probe.jsonl; nitya's
# spikes/token-probe/collect.sh reads that back. It runs as a dynamic user that gets the
# tokens as systemd credentials. A machine imports
# `inputs.nitya.nixosModules.token-probe` and this, and must define the four
# `age.secrets.nitya*` secrets (machines/ghost001.nix does).
{ ... }:
{
  # The nitya flake. nitya takes neusis as an input itself (its terranix stack), so its
  # neusis follows this flake rather than locking a second copy of the fleet.
  flake-file.inputs.nitya = {
    url = "github:leoank/nitya";
    inputs = {
      nixpkgs.follows = "nixpkgs-unstable";
      neusis.follows = "";
      yajna.follows = "yajna";
      flake-parts.follows = "flake-parts";
      terranix.follows = "terranix";
    };
  };

  flake.neusis.features.nixos.nitya-token-probe =
    { config, ... }:
    {
      services.nitya-token-probe = {
        enable = true;
        googleClientFile = config.age.secrets.nityaGoogleClient.path;
        googleTokenFile = config.age.secrets.nityaGoogleToken.path;
        microsoftTokenFile = config.age.secrets.nityaMicrosoftToken.path;
        icloudFile = config.age.secrets.nityaICloudToken.path;
      };
    };
}
