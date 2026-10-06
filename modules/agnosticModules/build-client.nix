# Distributed builds — CONSUMER side (agnostic module).
#
# Re-exported to `self.nixosModules.build-client` and
# `self.darwinModules.build-client`. Import it on any machine that should
# offload builds, then configure via `neusis.services.build-client`:
#
#   imports = [ self.darwinModules.build-client ];
#   neusis.services.build-client = {
#     enable   = true;
#     builders = self.neusis.registry.builders.anklab;   # or any list
#     sshKey   = config.age.secrets.remoteBuildKey.path;
#   };
#
# It turns each builder EXCEPT the local host (matched by hostName) into a
# `nix.buildMachines` entry, enables distributed builds, and pins each
# builder's SSH host key via `programs.ssh.knownHosts`. Self-contained —
# the builder list is passed in, so the module is reusable on its own.
#
# Each builder entry is an attrset:
#   { hostName; sshUser; systems; maxJobs; speedFactor;
#     supportedFeatures; mandatoryFeatures; hostPubkey;
#     sshKey ? <module default>; }
{ ... }:
{
  flake.agnosticModules.build-client =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.services.build-client;
      keep = b: !(cfg.excludeLocalhost && b.hostName == config.networking.hostName);
      active = builtins.filter keep cfg.builders;
    in
    {
      options.neusis.services.build-client = {
        enable = lib.mkEnableOption "nix distributed-builds consumer side";

        builders = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
          example = lib.literalExpression "self.neusis.registry.builders.anklab";
          description = ''
            Builder specs to offer as `nix.buildMachines`. Each entry:
            `{ hostName; sshUser; systems; maxJobs; speedFactor;
            supportedFeatures; mandatoryFeatures; hostPubkey; sshKey?; }`.
            The entry whose `hostName` matches this host is dropped (see
            `excludeLocalhost`).
          '';
        };

        sshKey = lib.mkOption {
          type = lib.types.str;
          default = "/etc/nix/remote-build-key";
          description = ''
            Default path to the private key used to reach builders. A
            builder entry may override it with its own `sshKey`.
          '';
        };

        protocol = lib.mkOption {
          type = lib.types.enum [
            "ssh"
            "ssh-ng"
          ];
          default = "ssh-ng";
          description = "SSH store protocol used to talk to builders.";
        };

        useSubstitutes = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Let builders fetch dependencies from substituters directly
            rather than copying every input over SSH (nix
            `builders-use-substitutes`).
          '';
        };

        excludeLocalhost = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Drop the builder whose `hostName` equals this host's name.";
        };
      };

      config = lib.mkIf cfg.enable {
        nix.distributedBuilds = true;
        nix.settings.builders-use-substitutes = cfg.useSubstitutes;

        nix.buildMachines = map (b: {
          inherit (b)
            hostName
            sshUser
            systems
            maxJobs
            speedFactor
            supportedFeatures
            mandatoryFeatures
            ;
          protocol = cfg.protocol;
          sshKey = b.sshKey or cfg.sshKey;
        }) active;

        # Pin builder host keys for SSH verification (used by nix's ssh
        # transport in place of a base64 publicHostKey).
        programs.ssh.knownHosts = builtins.listToAttrs (
          map (b: lib.nameValuePair b.hostName { publicKey = b.hostPubkey; }) active
        );
      };
    };
}
