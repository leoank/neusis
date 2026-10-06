# Neusis mesh — CSLab shared tailnet (agnostic feature, config-only).
#
# Adds the `cslab` tailscale profile (shntnu.github mesh). No OAuth creds in
# this copy, so force-claim / disable-expiry stay off (add cslab OAuth secrets
# to turn them on). Config-only: the tailscale *module* is imported by the
# machine (`self.<nixos|darwin>Modules.tailscale`).
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
      age.secrets.tsAuthKeyCslab.rekeyFile = ../../secrets/common/persistent_cslab_mesh.age;

      neusis.services.tailscale = {
        enable = true;
        defaultProfile = lib.mkDefault "cslab";
        profiles.cslab = {
          authKeyFile = config.age.secrets.tsAuthKeyCslab.path;
          hostName = config.networking.hostName;
          ephemeral = false;
          tailnetOrg = "shntnu.github";
        };
      };
    };
}
