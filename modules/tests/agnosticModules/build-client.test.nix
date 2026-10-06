# Tests for flake.agnosticModules.build-client: builder specs become
# nix.buildMachines entries (minus the local host) with pinned host keys.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;

      client = extra: {
        neusis.services.build-client = {
          enable = true;
          builders = f.builders;
        }
        // extra;
      };

      # The local host is called `fixture`, matching the first builder.
      darwinWith =
        extra:
        t.evalDarwin {
          modules = [
            self.darwinModules.build-client
            { networking.hostName = "fixture"; }
            (client extra)
          ];
        };
      nixosWith =
        extra:
        t.evalNixos {
          modules = [
            self.nixosModules.build-client
            { networking.hostName = "fixture"; }
            (client extra)
          ];
        };

      darwin = darwinWith { };
      nixos = nixosWith { };

      summary = cfg: {
        distributed = cfg.nix.distributedBuilds;
        substitutes = cfg.nix.settings.builders-use-substitutes;
        machines = map (m: {
          inherit (m)
            hostName
            sshUser
            systems
            maxJobs
            speedFactor
            supportedFeatures
            protocol
            sshKey
            ;
        }) cfg.nix.buildMachines;
        knownHosts = lib.mapAttrs (_: h: h.publicKey) cfg.programs.ssh.knownHosts;
        failed = t.failedAssertions cfg;
      };

      expectedSummary = {
        distributed = true;
        substitutes = true;
        # `fixture` is us and is dropped
        machines = [
          {
            hostName = "other-builder";
            sshUser = "nixremote";
            systems = [ "aarch64-linux" ];
            maxJobs = 8;
            speedFactor = 2;
            supportedFeatures = [ "kvm" ];
            protocol = "ssh-ng";
            sshKey = "/etc/nix/remote-build-key";
          }
        ];
        knownHosts.other-builder = f.hostPubkey;
        failed = [ ];
      };
    in
    {
      tests.agnostic-build-client = {
        test-darwin-offers-remote-builders-minus-self = {
          expr = summary darwin;
          expected = expectedSummary;
        };

        test-nixos-offers-remote-builders-minus-self = {
          expr = summary nixos;
          expected = expectedSummary;
        };

        test-exclude-localhost-off-keeps-self = {
          expr = map (m: m.hostName) (darwinWith { excludeLocalhost = false; }).nix.buildMachines;
          expected = [
            "fixture"
            "other-builder"
          ];
        };

        test-protocol-and-key-overrides = {
          expr =
            let
              cfg = nixosWith {
                protocol = "ssh";
                sshKey = "/root/.ssh/builder";
                useSubstitutes = false;
                builders = f.builders ++ [
                  (builtins.head f.builders // {
                    hostName = "keyed";
                    sshKey = "/root/.ssh/special";
                  })
                ];
              };
            in
            {
              keys = map (m: "${m.hostName}:${m.protocol}:${m.sshKey}") cfg.nix.buildMachines;
              substitutes = cfg.nix.settings.builders-use-substitutes;
            };
          expected = {
            keys = [
              "other-builder:ssh:/root/.ssh/builder"
              "keyed:ssh:/root/.ssh/special"
            ];
            substitutes = false;
          };
        };

        test-disabled-adds-no-builders = {
          expr =
            let
              cfg = t.evalDarwin { modules = [ self.darwinModules.build-client ]; };
            in
            {
              machines = cfg.nix.buildMachines;
              distributed = cfg.nix.distributedBuilds;
            };
          expected = {
            machines = [ ];
            distributed = false;
          };
        };
      };
    };
}
