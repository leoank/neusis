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
# (the agenix secret with NTFY_TOPIC and SENDGRID_API_KEY); the deploy
# log is written regardless.
{ self, ... }:
{
  flake.neusis.features.agnostic.auto-update =
    { config, lib, ... }:
    let
      au = self.neusis.lib.autoUpdate;
      groups = self.neusis.registry.deployGroups.anklab;
      host = config.networking.hostName;
      group = au.groupOf groups host;
    in
    {
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

      neusis.services.auto-update = {
        enable = true;
        url = "https://github.com/leoank/neusis.git";
        signers = self.neusis.registry.signers.anklab;
        notify = {
          emailFrom = "ghcibot@leoank.me";
          emailTo = [ "leoank98@gmail.com" ];
        };
      }
      // lib.optionalAttrs (group != null) {
        inherit (groups.${group}) branch;
        pollPeriod = lib.mkDefault groups.${group}.pollPeriod;
      };
    };
}
