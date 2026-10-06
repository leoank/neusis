# Tests for flake.neusis.lib.neusisOS (modules/lib/neusisOS.nix): registry
# helpers, per-role user builders, the two system builders and
# mkNeusisFlake. The NixOS paths are exercised nowhere else — the live
# registry has only Darwin hosts.
{ self, inputs, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;
      os = self.neusis.lib.neusisOS;

      usernames = map (u: u.username);

      # A registry with only a locked account: needs no password secret.
      lockedOnly = {
        admins = [ ];
        regulars = [ ];
        guests = [ ];
        locked = [ f.bob ];
      };

      passwordSecret = {
        age.secrets.commonInitialHashedPassword.file = f.machines.fixture.initialHashedPassword;
      };

      # Role builders on NixOS.
      nixosUsers = t.evalNixos {
        modules = [
          f.nixosLogin
          passwordSecret
          (os.mkAdmin f.alice)
          (os.mkRegular f.bob)
          (os.mkLocked {
            username = "carol";
            fullName = "Carol Locked";
            shell = "bash";
            sshKeys = [ ];
          })
        ];
      };

      # Role builders on Darwin.
      darwinUsers = t.evalDarwin {
        modules = [
          (os.mkAdmin f.alice)
          (os.mkLocked {
            username = "carol";
            fullName = "Carol Locked";
            shell = "bash";
            sshKeys = [ ];
          })
        ];
      };

      # Full NixOS system through mkNeusisOS with the fixture lab.
      fixtureOS =
        (os.mkNeusisOS {
          machineName = "fixture";
          userModule = f.machines.fixture.module;
          userRegistries = [ f.lab ];
          inherit (f.machines.fixture) initialHashedPassword;
        }).config;

      # Full Darwin system through mkNeusisDarwinOS.
      fixtureDarwin =
        (os.mkNeusisDarwinOS {
          machineName = "fixture-darwin";
          computerName = "Fixture Mac";
          primaryUser = "alice";
          userModule = f.machines.fixture-darwin.module;
          userRegistries = [ f.lab ];
        }).config;

      flakeOutputs = os.mkNeusisFlake {
        machineRegistries.lab = {
          nixos = [ f.machines.fixture ];
          darwin = [ f.machines.fixture-darwin ];
        };
      };
    in
    {
      tests.lib-neusisOS = {
        # ---- registry helpers

        test-merge-user-configs-concatenates-per-role = {
          expr = lib.mapAttrs (_: usernames) (
            os.mergeUserConfigs [
              f.lab
              lockedOnly
              { admins = [ f.bob ]; }
            ]
          );
          expected = {
            admins = [
              "alice"
              "bob"
            ];
            regulars = [ "bob" ];
            guests = [ ];
            # Regression: the key is `locked`, never `lockeds`.
            locked = [ "bob" ];
          };
        };

        test-concat-all-users-follows-role-order = {
          expr = usernames (
            os.concatAllUsers {
              admins = [ f.alice ];
              regulars = [ f.bob ];
              guests = [ { username = "guest"; } ];
              locked = [ { username = "locked"; } ];
            }
          );
          expected = [
            "alice"
            "bob"
            "guest"
            "locked"
          ];
        };

        test-mk-dynamic-users-one-module-per-user = {
          expr = builtins.length (os.mkDynamicUsers [ f.lab lockedOnly ]);
          expected = 3;
        };

        # ---- per-role builders, NixOS

        test-nixos-admin-account = {
          expr =
            let
              u = nixosUsers.users.users.alice;
            in
            {
              description = u.description;
              isNormalUser = u.isNormalUser;
              wheel = builtins.elem "wheel" u.extraGroups;
              shell = lib.getName u.shell;
              passwordFile = u.hashedPasswordFile;
            };
          expected = {
            description = "Alice Fixture";
            isNormalUser = true;
            wheel = true;
            shell = "zsh";
            passwordFile = "/run/agenix/commonInitialHashedPassword";
          };
        };

        test-nixos-regular-has-no-wheel = {
          expr =
            let
              u = nixosUsers.users.users.bob;
            in
            {
              wheel = builtins.elem "wheel" u.extraGroups;
              docker = builtins.elem "docker" u.extraGroups;
            };
          expected = {
            wheel = false;
            docker = true;
          };
        };

        test-nixos-locked-account-cannot-login = {
          expr =
            let
              u = nixosUsers.users.users.carol;
            in
            {
              shell = lib.hasSuffix "/bin/nologin" (toString u.shell);
              hashedPassword = u.hashedPassword;
              hasPasswordFile = u.hashedPasswordFile != null;
              groups = u.extraGroups;
            };
          expected = {
            shell = true;
            hashedPassword = "!";
            hasPasswordFile = false;
            groups = [ "input" ];
          };
        };

        test-nixos-users-pass-assertions = {
          expr = t.failedAssertions nixosUsers;
          expected = [ ];
        };

        # ---- per-role builders, Darwin

        test-darwin-admin-account-gets-home-dir = {
          expr =
            let
              u = darwinUsers.users.users.alice;
            in
            {
              description = u.description;
              home = u.home;
              shell = lib.getName u.shell;
            };
          expected = {
            description = "Alice Fixture";
            home = "/Users/alice";
            shell = "zsh";
          };
        };

        test-darwin-locked-account-uses-false-shell = {
          expr = toString darwinUsers.users.users.carol.shell;
          expected = "/usr/bin/false";
        };

        # ---- mkNeusisOS

        test-mk-neusis-os-requires-initial-password-for-login-users = {
          expr =
            (os.mkNeusisOS {
              machineName = "nopw";
              userModule = f.machines.fixture.module;
              userRegistries = [ f.lab ];
            }).config.networking.hostName;
          expectedError = {
            type = "ThrownError";
            msg = "has login \\(non-locked\\) users but no";
          };
        };

        test-mk-neusis-os-locked-only-needs-no-password = {
          expr =
            (os.mkNeusisOS {
              machineName = "lockedbox";
              userModule = f.machines.fixture.module;
              userRegistries = [ lockedOnly ];
            }).config.networking.hostName;
          expected = "lockedbox";
        };

        test-mk-neusis-os-no-registries-skips-home-manager = {
          expr =
            (os.mkNeusisOS {
              machineName = "bare";
              userModule = f.nixosBase;
            }).config
            ? home-manager;
          expected = false;
        };

        test-mk-neusis-os-sets-platform-and-hostname = {
          expr = {
            host = fixtureOS.networking.hostName;
            system = fixtureOS.nixpkgs.hostPlatform.system;
          };
          expected = {
            host = "fixture";
            system = "x86_64-linux";
          };
        };

        test-mk-neusis-os-wires-home-manager-from-bundles-map = {
          expr = {
            # alice maps bundles to `fixture`; bob maps nothing.
            hmUsers = builtins.attrNames fixtureOS.home-manager.users;
            alicePkgs = t.hasPkg "hello" fixtureOS.home-manager.users.alice.home.packages;
            stateVersion = fixtureOS.home-manager.users.alice.home.stateVersion;
            backupExt = fixtureOS.home-manager.backupFileExtension;
            accounts = builtins.attrNames (
              lib.filterAttrs (_: u: u.isNormalUser) fixtureOS.users.users
            );
          };
          expected = {
            hmUsers = [ "alice" ];
            alicePkgs = true;
            stateVersion = "25.11";
            backupExt = "bak";
            accounts = [
              "alice"
              "bob"
            ];
          };
        };

        test-mk-neusis-os-passes-assertions = {
          expr = t.failedAssertions fixtureOS;
          expected = [ ];
        };

        # ---- mkNeusisDarwinOS

        test-mk-neusis-darwin-os-rejects-nixpkgs-override = {
          expr =
            (os.mkNeusisDarwinOS {
              machineName = "mac";
              userModule = { };
              nixpkgs = inputs.nixpkgs-unstable;
            }).config.networking.hostName;
          expectedError = {
            type = "ThrownError";
            msg = "per-machine `nixpkgs` overrides aren't supported on Darwin";
          };
        };

        test-mk-neusis-darwin-os-wires-identity-and-home-manager = {
          expr = {
            host = fixtureDarwin.networking.hostName;
            computerName = fixtureDarwin.networking.computerName;
            primaryUser = fixtureDarwin.system.primaryUser;
            hmUsers = builtins.attrNames fixtureDarwin.home-manager.users;
            useUserPackages = fixtureDarwin.home-manager.useUserPackages;
            aliceHome = fixtureDarwin.users.users.alice.home;
            failed = t.failedAssertions fixtureDarwin;
          };
          expected = {
            host = "fixture-darwin";
            computerName = "Fixture Mac";
            primaryUser = "alice";
            hmUsers = [ "alice" ];
            useUserPackages = true;
            aliceHome = "/Users/alice";
            failed = [ ];
          };
        };

        # ---- mkNeusisFlake

        test-mk-neusis-flake-output-names = {
          expr = lib.mapAttrs (_: builtins.attrNames) flakeOutputs;
          expected = {
            nixosConfigurations = [ "fixture" ];
            darwinConfigurations = [ "fixture-darwin" ];
            # bob has no machineToBundlesMap entry, so no home for him.
            homeConfigurations = [
              "alice@fixture"
              "alice@fixture-darwin"
            ];
          };
        };

        test-mk-neusis-flake-standalone-homes-get-identity = {
          expr =
            let
              linux = flakeOutputs.homeConfigurations."alice@fixture".config;
              mac = flakeOutputs.homeConfigurations."alice@fixture-darwin".config;
            in
            {
              linuxHome = linux.home.homeDirectory;
              macHome = mac.home.homeDirectory;
              user = mac.home.username;
              stateVersion = linux.home.stateVersion;
              hasHello = t.hasPkg "hello" linux.home.packages;
            };
          expected = {
            linuxHome = "/home/alice";
            macHome = "/Users/alice";
            user = "alice";
            stateVersion = "25.11";
            hasHello = true;
          };
        };
      };
    };
}
