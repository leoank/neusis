# Invariants of the real `rogue` host and `ank@rogue` home. These evaluate
# the live configurations and encode policy: stateVersions are never
# bumped with nixpkgs; the primary user, hostname, mesh/builders wiring.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = self.darwinConfigurations.rogue.config;
      home = self.homeConfigurations."ank@rogue".config;
      m = self.neusis.machines.rogue;
    in
    {
      tests.machine-rogue = {
        test-identity = {
          expr = {
            host = cfg.networking.hostName;
            computerName = cfg.networking.computerName;
            primaryUser = cfg.system.primaryUser;
            platform = self.darwinConfigurations.rogue.pkgs.stdenv.hostPlatform.system;
            homebrewUser = cfg.nix-homebrew.user;
            hostPubkey = cfg.neusis.services.secrets.hostPubkey == m.hostPubkey;
          };
          expected = {
            host = "rogue";
            computerName = "rogue";
            primaryUser = "ank";
            platform = "aarch64-darwin";
            homebrewUser = "ank";
            hostPubkey = true;
          };
        };

        # Policy: stateVersion records the release a host/home was created
        # under and is NOT bumped with nixpkgs (AGENTS.md).
        test-state-versions-are-pinned = {
          expr = {
            system = cfg.system.stateVersion;
            homeIntegrated = cfg.home-manager.users.ank.home.stateVersion;
            homeStandalone = home.home.stateVersion;
          };
          expected = {
            system = 5;
            homeIntegrated = "25.11";
            homeStandalone = "25.11";
          };
        };

        test-users-and-homes = {
          expr = {
            hmUsers = builtins.attrNames cfg.home-manager.users;
            ankShell = lib.getName cfg.users.users.ank.shell;
            ankHome = cfg.users.users.ank.home;
            standaloneUser = home.home.username;
            standaloneHome = home.home.homeDirectory;
            # the same bundles power the integrated and standalone homes
            kalam = t.hasPkg "nixvim" home.home.packages && t.hasPkg "nixvim" cfg.home-manager.users.ank.home.packages;
            neusisCli = t.hasPkg "neusis" home.home.packages;
          };
          expected = {
            hmUsers = [ "ank" ];
            ankShell = "zsh";
            ankHome = "/Users/ank";
            standaloneUser = "ank";
            standaloneHome = "/Users/ank";
            kalam = true;
            neusisCli = true;
          };
        };

        test-services = {
          expr = {
            linuxBuilder = cfg.nix.linux-builder.enable;
            kanata = cfg.neusis.services.kanata.enable;
            buildServer = cfg.neusis.services.build-server.enable;
            buildsOffloadTo = map (b: b.hostName) cfg.nix.buildMachines;
            # meshes are commented out on rogue: daemon present, no profiles
            tailscale = cfg.neusis.services.tailscale.enable;
            homebrew = cfg.homebrew.enable;
            ssh = cfg.services.openssh.enable;
          };
          expected = {
            linuxBuilder = true;
            kanata = true;
            buildServer = true;
            # darwin001 from the registry + the local linux-builder VM
            buildsOffloadTo = [
              "darwin001"
              "linux-builder"
            ];
            tailscale = false;
            homebrew = true;
            ssh = true;
          };
        };

        test-no-failed-assertions = {
          expr = {
            system = t.failedAssertions cfg;
            home = t.failedAssertions home;
          };
          expected = {
            system = [ ];
            home = [ ];
          };
        };
      };
    };
}
