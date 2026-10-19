# Stack `oci-anklab`: provision. The anklab network on OCI and the
# instances on it, each bound to a neusis machine. Boots the custom image
# baked by `oci-images` (looked up by name) and ignores later image
# changes, so re-baking never replaces a host (spec §5.3).
#
#   nix run .#oci-anklab.plan / .apply
#   nix run .#oci-anklab.terraform -- output -json    # IPs for bootstrap
#
# Working dir infra/oci-anklab (encrypted state committed there).
{ self, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      checks.tofu-validate-oci-anklab = self.neusis.lib.cloud.mkValidateCheck {
        inherit pkgs;
        name = "oci-anklab";
        modules = config.terranix.terranixConfigurations.oci-anklab.modules;
      };

      terranix.terranixConfigurations.oci-anklab.modules = with self.terranixModules; [
        state-encryption
        oci-provider
        oci-network
        oci-instance
        {
          neusis.oci.network.anklab = {
            cidr = "10.42.0.0/16";
            # Decision §12.8: public SSH stays open after bootstrap; flip
            # to false for tailnet-only access.
            publicSsh = true;
          };

          # Always Free A1 budget: 4 OCPUs / 24 GB and 200 GB of block
          # storage in total — 50 GB boot (the minimum) + 150 GB for app
          # state on a separate volume that survives reprovisioning.
          neusis.oci.instances.ghost001 = {
            machine = self.neusis.machines.ghost001;
            network = "anklab";
            image = "oci-base-aarch64";
            shape = {
              name = "VM.Standard.A1.Flex";
              ocpus = 4;
              memoryGb = 24;
            };
            bootVolumeGb = 50;
            dataVolumeGb = 150;
            reservedIp = true;
            # Root on first boot (via instance metadata) — ank's keys from
            # the user registry.
            sshAuthorizedKeys = map (f: lib.removeSuffix "\n" (builtins.readFile f)) self.neusis.users.ank.neusisOS.sshKeys;
          };
        }
      ];
    };
}
