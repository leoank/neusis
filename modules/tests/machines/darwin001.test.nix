# Invariants of the real `darwin001` host and `kumarank@darwin001` home.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = self.darwinConfigurations.darwin001.config;
      home = self.homeConfigurations."kumarank@darwin001".config;
      m = self.neusis.machines.darwin001;
    in
    {
      tests.machine-darwin001 = {
        test-identity = {
          expr = {
            host = cfg.networking.hostName;
            computerName = cfg.networking.computerName;
            primaryUser = cfg.system.primaryUser;
            platform = self.darwinConfigurations.darwin001.pkgs.stdenv.hostPlatform.system;
            homebrewUser = cfg.nix-homebrew.user;
            hostPubkey = cfg.neusis.services.secrets.hostPubkey == m.hostPubkey;
          };
          expected = {
            host = "darwin001";
            computerName = "darwin001";
            primaryUser = "kumarank";
            platform = "aarch64-darwin";
            homebrewUser = "kumarank";
            hostPubkey = true;
          };
        };

        test-state-versions-are-pinned = {
          expr = {
            system = cfg.system.stateVersion;
            homeIntegrated = cfg.home-manager.users.kumarank.home.stateVersion;
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
            shell = lib.getName cfg.users.users.kumarank.shell;
            home = cfg.users.users.kumarank.home;
            standaloneUser = home.home.username;
            standaloneHome = home.home.homeDirectory;
            # same human, same bundles as ank
            kalam = t.hasPkg "nixvim" home.home.packages;
            gitIdentity = home.programs.git.settings.user.email;
          };
          expected = {
            hmUsers = [ "kumarank" ];
            shell = "zsh";
            home = "/Users/kumarank";
            standaloneUser = "kumarank";
            standaloneHome = "/Users/kumarank";
            kalam = true;
            gitIdentity = "ank@leoank.me";
          };
        };

        test-services = {
          expr = {
            # linux-builder is rogue-only
            linuxBuilder = cfg.nix.linux-builder.enable;
            kanata = cfg.neusis.services.kanata.enable;
            buildsOffloadTo = map (b: b.hostName) cfg.nix.buildMachines;
            tailscale = cfg.neusis.services.tailscale.enable;
            defaultMesh = cfg.neusis.services.tailscale.defaultProfile;
            meshes = builtins.attrNames cfg.neusis.services.tailscale.profiles;
            meshHostName = cfg.neusis.services.tailscale.profiles.leoank.hostName;
          };
          expected = {
            linuxBuilder = false;
            kanata = true;
            buildsOffloadTo = [ "rogue" ];
            tailscale = true;
            defaultMesh = "leoank";
            meshes = [
              "cslab"
              "leoank"
            ];
            meshHostName = "darwin001";
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
