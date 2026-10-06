# T3: the fixture NixOS machine, booted as a VM from exactly the module
# list `mkNeusisOS` assembles (`mkNeusisOSModules`). Proves the whole
# chain works at runtime: accounts and groups per role, the agenix-seeded
# initial password, home-manager activation from `machineToBundlesMap`.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;
      os = self.neusis.lib.neusisOS;
      m = f.machines.vm;
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-neusis-os = t.mkVmTest pkgs {
          name = "vm-neusis-os";

          nodes.fixture.imports = os.mkNeusisOSModules {
            machineName = m.hostname;
            userModule = m.module;
            userRegistries = m.userRegistries;
            initialHashedPassword = m.initialHashedPassword;
            # platform comes from the test framework
          };

          testScript = ''
            fixture.wait_for_unit("multi-user.target")

            with subtest("accounts follow the registry roles"):
                fixture.succeed("getent passwd alice | grep -q '/home/alice:.*/zsh$'")
                fixture.succeed("getent passwd bob | grep -q '/home/bob:.*/bash$'")
                assert "wheel" in fixture.succeed("id -nG alice").split(), "alice (admin) should be in wheel"
                assert "wheel" not in fixture.succeed("id -nG bob").split(), "bob (regular) must not be in wheel"
                # (role groups like docker/libvirtd only apply where those groups exist)

            with subtest("agenix decrypts the initial password and seeds every login account"):
                secret = fixture.succeed("cat /run/agenix/commonInitialHashedPassword").strip()
                assert secret.startswith("$6$"), f"unexpected hash: {secret!r}"
                for user in ["alice", "bob"]:
                    shadow = fixture.succeed(f"getent shadow {user}").split(":")[1]
                    assert shadow == secret, f"{user}'s shadow entry is not the seeded hash"

            with subtest("home-manager activates alice's bundles and nobody else's"):
                fixture.wait_for_unit("home-manager-alice.service")
                fixture.succeed("su - alice -c '/home/alice/.nix-profile/bin/hello' | grep -q 'Hello, world'")
                fixture.fail("systemctl cat home-manager-bob.service")

            with subtest("hostname comes from the machine"):
                assert fixture.succeed("hostname").strip() == "fixture"
          '';
        };
      };
    };
}
