# Tests for flake.neusis.features.agnostic.distributed-builds: build-server
# + build-client wired to the anklab builders registry and the
# remoteBuildKey secret. Composed with the secrets module the way the
# machines do. Darwin only here — build-server does not evaluate on NixOS
# (pinned in agnosticModules/build-server.test.nix).
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;

      onHost =
        host:
        t.evalDarwin {
          modules = [
            inputs.agenix.darwinModules.default
            inputs.agenix-rekey.darwinModules.default
            self.darwinModules.secrets
            {
              networking.hostName = host;
              neusis.services.secrets = {
                enable = true;
                hostPubkey = f.hostPubkey;
                masterIdentities = [
                  {
                    identity = "/Users/alice/.ssh/id_ed25519";
                    pubkey = f.hostPubkey;
                  }
                ];
              };
            }
            self.neusis.features.agnostic.distributed-builds
          ];
        };

      rogue = onHost "rogue";
    in
    {
      tests.feature-distributed-builds = {
        test-rogue-serves-and-offloads-to-the-linux-builders = {
          expr = {
            server = rogue.neusis.services.build-server.enable;
            serverKeyFiles = map baseNameOf rogue.neusis.services.build-server.authorizedKeyFiles;
            buildUser = builtins.elem "nixremote" rogue.users.knownUsers;
            trusted = builtins.elem "nixremote" rogue.nix.settings.trusted-users;
            client = rogue.neusis.services.build-client.enable;
            machines = map (m: m.hostName) rogue.nix.buildMachines;
            sshKey = lib.unique (map (m: m.sshKey) rogue.nix.buildMachines);
            knownHosts = builtins.attrNames (lib.filterAttrs (_: _: true) rogue.programs.ssh.knownHosts);
            failed = t.failedAssertions rogue;
          };
          expected = {
            server = true;
            serverKeyFiles = [ "remote-build.pub" ];
            buildUser = true;
            trusted = true;
            client = true;
            # darwin001 is not a builder (see registry/builders/anklab.nix)
            machines = [
              "spirit"
              "oppy"
            ];
            sshKey = [ "/etc/nix/remote-build-key" ];
            knownHosts = [
              "oppy"
              "spirit"
            ];
            failed = [ ];
          };
        };

        test-darwin001-offloads-to-rogue = {
          expr = map (m: "${m.hostName}:${toString m.maxJobs}:${toString m.speedFactor}") (onHost "darwin001").nix.buildMachines;
          expected = [
            "spirit:12:10"
            "oppy:12:10"
            "rogue:8:2"
          ];
        };

        test-unregistered-host-offers-every-builder = {
          expr = map (m: m.hostName) (onHost "laptop").nix.buildMachines;
          expected = [
            "spirit"
            "oppy"
            "rogue"
          ];
        };
      };
    };
}
