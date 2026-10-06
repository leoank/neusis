# T3: the agnostic tailscale module on NixOS. No tailnet is reachable from
# the VM, so the test checks the daemon runs, the autoconnect oneshot
# exists with the right shape and really executes our profile script, and
# the per-profile switch commands are on PATH.
{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      t = self.neusis.lib.tests;
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-tailscale = t.mkVmTest pkgs {
          name = "vm-tailscale";

          nodes.machine = {
            imports = [ self.nixosModules.tailscale ];
            neusis.services.tailscale = {
              enable = true;
              defaultProfile = "lab";
              profiles.lab = {
                hostName = "fixture";
                extraUpFlags = [ "--ssh" ];
              };
              profiles.other = { };
            };
          };

          testScript = ''
            # Don't wait for multi-user.target: the autoconnect oneshot blocks
            # on an interactive login it can never finish here.
            machine.wait_for_unit("tailscaled.service")

            with subtest("daemon answers the CLI"):
                machine.wait_until_succeeds("tailscale status --json 2>&1 | grep -Eq 'BackendState|Logged out|NeedsLogin'")

            with subtest("autoconnect unit has the documented shape"):
                unit = machine.succeed("systemctl cat neusis-tailscale-autoconnect.service")
                assert "Type=oneshot" in unit, unit
                assert "RemainAfterExit=true" in unit, unit
                assert "neusis-ts-lab" in unit, "ExecStart should run the default profile's script"
                assert "tailscaled.service" in unit, "must be ordered after tailscaled"

            with subtest("autoconnect actually ran the profile script"):
                machine.wait_until_succeeds(
                    "journalctl -u neusis-tailscale-autoconnect | grep -q 'creating/authenticating profile: lab'"
                )

            with subtest("switch scripts for every profile are on PATH"):
                machine.succeed("command -v neusis-ts-lab", "command -v neusis-ts-other", "command -v tailscale")
          '';
        };
      };
    };
}
