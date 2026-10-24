# Neusis mesh — CSLab shared tailnet (agnostic feature, config-only).
#
# Adds the `cslab` tailscale profile (shntnu.github mesh) with hostname
# force-claim + non-expiring key (OAuth client from secrets/common/).
# Config-only: the tailscale *module* is imported by the machine
# (`self.<nixos|darwin>Modules.tailscale`).
#
# `defaultProfile` is set via `mkDefault "cslab"` so that:
#   * imported alone      → cslab is the boot default;
#   * imported with ank_mesh → ank_mesh's normal-priority "leoank" wins.
# A machine can override with `neusis.services.tailscale.defaultProfile = …`.
#
# `--hostname` is the machine's own hostname. See ank_mesh.nix for the full
# import recipe.
{ ... }:
{
  flake.neusis.features.agnostic.cslab_mesh =
    { config, lib, ... }:
    {
      # cslab tailnet credentials: the auth key lives in secrets/cslab/, the
      # OAuth client (force-claim / key-expiry) is the shared one in
      # secrets/common/ (tsclient = id, tssecret = secret). Edit with
      # `agenix edit modules/secrets/<dir>/<name>.age`, then `agenix rekey`.
      age.secrets = {
        tsAuthKeyCslab.rekeyFile = ../../secrets/cslab/tsAuthKeyCslab.age;
        tsClientIdCslab.rekeyFile = ../../secrets/common/tsclient.age;
        tsClientSecretCslab.rekeyFile = ../../secrets/common/tssecret.age;
      };

      neusis.services.tailscale = {
        enable = true;
        defaultProfile = lib.mkDefault "cslab";
        profiles.cslab = {
          authKeyFile = config.age.secrets.tsAuthKeyCslab.path;
          hostName = config.networking.hostName;
          ephemeral = false;
          forceHostName = true;
          tailnetOrg = "shntnu.github";
          clientIdFile = config.age.secrets.tsClientIdCslab.path;
          clientSecretFile = config.age.secrets.tsClientSecretCslab.path;
          disableKeyExpiry = true;
        };
      };
    };
}
