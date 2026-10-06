# Neusis mesh — ank's personal tailnet (agnostic feature, config-only).
#
# Adds the `leoank` tailscale profile (personal tailnet) and makes it the boot
# default, with hostname force-claim + non-expiring key (OAuth creds present).
# Config-only: the tailscale *module* is imported by the machine
# (`self.<nixos|darwin>Modules.tailscale`); this just fills in profile + secrets.
#
# Composes with `cslab_mesh`: importing both yields profiles { leoank, cslab }
# with `leoank` as the default (this feature sets `defaultProfile` at normal
# priority, cslab_mesh sets it via `mkDefault`). A consuming machine needs:
#
#   imports = [
#     inputs.agenix.<nixos|darwin>Modules.default
#     inputs.agenix-rekey.<nixos|darwin>Modules.default
#     self.<nixos|darwin>Modules.secrets
#     self.<nixos|darwin>Modules.tailscale            # the tailscale module
#     self.neusis.features.agnostic.ank_mesh          # this
#     self.neusis.features.agnostic.cslab_mesh        # optional, additional
#   ];
#   neusis.services.secrets = { enable = true; hostPubkey = …; masterIdentities = …; };
#
# `--hostname` is the machine's own hostname.
{ ... }:
{
  flake.neusis.features.agnostic.ank_mesh =
    { config, ... }:
    {
      age.secrets = {
        tsAuthKeyLeoank.rekeyFile = ../../secrets/common/persistent_tsauthkey.age;
        tsClientId.rekeyFile = ../../secrets/common/tsclient.age;
        tsClientSecret.rekeyFile = ../../secrets/common/tssecret.age;
      };

      neusis.services.tailscale = {
        enable = true;
        defaultProfile = "leoank";
        profiles.leoank = {
          authKeyFile = config.age.secrets.tsAuthKeyLeoank.path;
          hostName = config.networking.hostName;
          ephemeral = false;
          forceHostName = true;
          tailnetOrg = "leoank.github";
          clientIdFile = config.age.secrets.tsClientId.path;
          clientSecretFile = config.age.secrets.tsClientSecret.path;
          disableKeyExpiry = true;
        };
      };
    };
}
