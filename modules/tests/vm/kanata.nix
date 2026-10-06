# T3: the agnostic kanata module on NixOS. The VM has no physical keyboard;
# nixpkgs's synthesized defcfg carries `linux-continue-if-no-devs-found`, so
# the service must come up and stay up with a config-body keyboard.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      t = self.neusis.lib.tests;
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-kanata = t.mkVmTest pkgs {
          name = "vm-kanata";

          nodes.machine = {
            imports = [ self.nixosModules.kanata ];
            neusis.services.kanata = {
              enable = true;
              # replace the shipped custom.kbd (a complete file) with a
              # synthesized config so nixpkgs adds the no-devices flag
              keyboards = lib.mkForce {
                vm = {
                  config = ''
                    (defsrc caps)
                    (deflayer base esc)
                  '';
                  extraDefCfg = "process-unmapped-keys yes";
                };
              };
            };
          };

          testScript = ''
            machine.wait_for_unit("multi-user.target")
            try:
                machine.wait_for_unit("kanata-vm.service")
            except Exception:
                # surface why kanata died (device/uinput access etc.)
                print(machine.execute("journalctl -b -u kanata-vm.service --no-pager")[1])
                print(machine.execute("ls -l /dev/uinput /dev/input; lsmod | grep -i uinput")[1])
                raise

            with subtest("kanata stays running without a keyboard"):
                machine.sleep(5)
                assert machine.succeed("systemctl is-active kanata-vm.service").strip() == "active"

            with subtest("the unit runs our package with the synthesized config"):
                unit = machine.succeed("systemctl cat kanata-vm.service")
                assert "/bin/kanata" in unit, unit
                cfg = machine.succeed(
                    "systemctl show -p ExecStart --value kanata-vm.service | grep -o -- '--cfg [^ ;]*' | awk '{print $2}'"
                ).strip()
                assert cfg.startswith("/nix/store/"), f"no --cfg store path in ExecStart: {unit}"
                machine.succeed(f"grep -q linux-continue-if-no-devs-found {cfg}")
                machine.succeed(f"grep -q process-unmapped-keys {cfg}")

            with subtest("the CLI is installed system-wide"):
                machine.succeed("kanata --version")
          '';
        };
      };
    };
}
