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
  flake.neusis.registry.builders.anklab = [
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
    {
      hostName = m.darwin001.hostname;
      sshUser = "nixremote";
      systems = [ m.darwin001.system ];
      maxJobs = 4;
      speedFactor = 1;
      supportedFeatures = [
        "big-parallel"
      ];
      mandatoryFeatures = [ ];
      hostPubkey = m.darwin001.hostPubkey;
    }
  ];
}
