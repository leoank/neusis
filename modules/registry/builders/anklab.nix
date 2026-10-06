# Curated remote-builder registry.
#
# Each entry is a machine offered as a nix distributed-builds builder,
# with its own capabilities and tuning. Host identity (hostname, system,
# host key) is pulled from the machine defs so there's a single source of
# truth; the builder-specific parameters (maxJobs, speedFactor, feature
# sets) live here because they're per-builder policy, not machine facts.
#
# Consumed by `features/agnostic/build-client.nix`, which turns this list
# into `nix.buildMachines` on each host (excluding the host itself).
#
# `sshUser` must match the build user created by
# `features/agnostic/build-server.nix` on the builder.
{ self, ... }:
let
  m = self.neusis.machines;
in
{
  # Builders every anklab host offers to its peers (build-client drops the
  # entry matching its own hostname). darwin001 is deliberately NOT a
  # builder: Nix sends a derivation to any eligible remote with a free
  # slot before building locally, so rogue's own Darwin builds would queue
  # on darwin001's four slow slots first. darwin001 still offloads to
  # rogue and the Linux builders.
  flake.neusis.registry.builders.anklab = [
    {
      hostName = "spirit";
      sshUser = "ank";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # Their daemons run `cores = 0` (every build may use all 384
      # threads), so cap concurrency here instead: a dozen jobs keep the
      # box busy without parallel-internal builds fighting each other.
      maxJobs = 12;
      speedFactor = 10;
      supportedFeatures = [
        "big-parallel"
        "benchmark"
        "kvm"
        "nixos-test"
      ];
      mandatoryFeatures = [ ];
      hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJUYYQCN1rhnyZ8HIIy4SgF3wvoapeqiCJRhfusTDFiK";
    }
    {
      hostName = "oppy";
      sshUser = "ank";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # Their daemons run `cores = 0` (every build may use all 384
      # threads), so cap concurrency here instead: a dozen jobs keep the
      # box busy without parallel-internal builds fighting each other.
      maxJobs = 12;
      speedFactor = 10;
      supportedFeatures = [
        "big-parallel"
        "benchmark"
        "kvm"
        "nixos-test"
      ];
      mandatoryFeatures = [ ];
      hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINCW3CZ4r7VhI7+4rC+oOE4n3AMXEy3F2vm8jjHeTClR";
    }
    {
      hostName = m.rogue.hostname;
      sshUser = "nixremote";
      systems = [ m.rogue.system ];
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [
        "big-parallel"
        "benchmark"
      ];
      mandatoryFeatures = [ ];
      hostPubkey = m.rogue.hostPubkey;
    }
  ];
}
