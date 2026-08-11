# Distributed builds wiring (agnostic feature).
#
# Bundles the serving + consumer sides of nix distributed builds. Works
# on NixOS and nix-darwin.
#
# It does NOT wire secrets — that's machine-level config (per-host
# `hostPubkey`, operator `masterIdentities`). The consuming machine must
# separately import + enable the secrets module so that the
# `remoteBuildKey` secret this feature reads for `sshKey` exists:
#
#   imports = [
#     inputs.agenix.<nixos|darwin>Modules.default
#     inputs.agenix-rekey.<nixos|darwin>Modules.default
#     self.<nixos|darwin>Modules.secrets
#     self.neusis.features.agnostic.distributed-builds
#   ];
#   neusis.services.secrets = { enable = true; hostPubkey = …; masterIdentities = …; };
#
# Both current hosts are builder AND consumer, so this enables both; each
# host drops itself from its own builder list (build-client.excludeLocalhost).
{ self, ... }:
{
  flake.neusis.features.agnostic.distributed-builds =
    {
      config,
      ...
    }:
    {
      imports = [
        self.agnosticModules.build-server
        self.agnosticModules.build-client
      ];

      neusis.services.build-server = {
        enable = true;
        authorizedKeyFiles = [ ../../secrets/common/remote-build.pub ];
      };

      neusis.services.build-client = {
        enable = true;
        builders = self.neusis.registry.builders.anklab;
        # private key delivered by agenix (the remoteBuildKey secret,
        # declared by the machine's secrets module).
        sshKey = config.age.secrets.remoteBuildKey.path;
      };
    };
}
