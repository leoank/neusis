# T3: the flake's own packages run inside a NixOS VM — the neusis CLI,
# gclb, and kalam (neovim headless with every plugin loaded).
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      t = self.neusis.lib.tests;
      p = self.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-packages = t.mkVmTest pkgs {
          name = "vm-packages";

          nodes.machine = {
            environment.systemPackages = [
              p.neusis
              p.gclb
              p.kalam
            ];
          };

          testScript = ''
            machine.wait_for_unit("multi-user.target")

            with subtest("neusis CLI"):
                help = machine.succeed("neusis --help")
                for sub in ["init", "add", "anywhere"]:
                    assert sub in help, f"neusis --help should list {sub!r}"

            with subtest("gclb is installed and runs"):
                machine.succeed("gclb --help")

            with subtest("kalam starts headless with its plugins"):
                out = machine.succeed("HOME=/root nvim --headless '+lua print(\"kalam-ok\")' +qa 2>&1")
                assert "kalam-ok" in out, out
                assert "Error" not in out, out
          '';
        };
      };
    };
}
