# Auto-updates for anklab hosts (agnostic feature, config-only).
#
# Points `neusis.services.auto-update` at this repo: the host follows the
# branch of the anklab deploy group it is in
# (`registry.deployGroups.anklab`), deploys only heads signed by an
# anklab signer (`registry.signers.anklab`) and mails failures from
# ghcibot@leoank.me to leoank98@gmail.com. The modules are imported by
# the machine, per platform:
#
#   imports = [
#     inputs.comin.<nixos|darwin>Modules.comin
#     self.<nixos|darwin>Modules.auto-update
#     self.neusis.features.agnostic.auto-update
#   ];
#
# A host outside every group fails an assertion. Notifications stay off
# until the machine sets `neusis.services.auto-update.notify.environmentFile`
# (the agenix secret with POSTMARK_API_KEY, and NTFY_TOPIC in phase 2);
# the deploy log is written regardless. Success pings go to ntfy only, so
# they are off until ntfy exists (docs/auto-update-spec.md §6.4).
#
# On darwin it turns off home-manager's App Management check: comin's
# root daemon lacks that macOS permission, so the check aborted every
# unattended deploy (docs/porting.md, 2026-11-01).
{ self, ... }:
{
  flake.neusis.features.agnostic.auto-update =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      au = self.neusis.lib.autoUpdate;
      groups = self.neusis.registry.deployGroups.anklab;
      host = config.networking.hostName;
      group = au.groupOf groups host;
    in
    {
      config = {
        assertions = [
          {
            assertion = au.checkGroups groups == [ ];
            message = "anklab deploy groups are invalid: ${lib.concatStringsSep "; " (au.checkGroups groups)}";
          }
          {
            assertion = group != null;
            message = "auto-update: ${host} is in no anklab deploy group (modules/registry/deploy-groups/anklab.nix).";
          }
        ];

        # The commit this system was built from, which the switch check
        # compares with the deploy branch (null for an unknown tree). It also
        # gives every commit its own generation, even one that only touches docs.
        system.configurationRevision = lib.mkDefault (self.rev or self.dirtyRev or null);

        neusis.services.auto-update = {
          enable = true;
          url = "https://github.com/leoank/neusis.git";
          signers = self.neusis.registry.signers.anklab;
          notify = {
            emailFrom = "ghcibot@leoank.me";
            emailTo = [ "leoank98@gmail.com" ];
            onSuccess = false;
          };
        }
        // lib.optionalAttrs (group != null) {
          inherit (groups.${group}) branch;
          pollPeriod = lib.mkDefault groups.${group}.pollPeriod;
        };
      }
      // lib.optionalAttrs (options ? launchd && options ? home-manager) {
        home-manager.sharedModules = [
          { targets.darwin.copyApps.enableChecks = lib.mkDefault false; }
        ];
      };
    };
}
