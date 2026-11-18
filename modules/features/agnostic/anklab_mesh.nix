# Neusis mesh — the tailnets ank can join through anklab (agnostic feature,
# config-only). Replaces `cslab_mesh`, one machine at a time.
#
# Every network is a tailscale profile named after it, with three secrets in
# secrets/anklab/: `<profile>TsAuthKey`, `<profile>TsClientId` and
# `<profile>TsClientSecret` (an OAuth client of that tailnet, for the hostname
# force-claim and the non-expiring key). Adding a network = its three
# secrets + its name in `profiles` below. Edit with
# `agenix edit modules/secrets/anklab/<name>.age`, then `agenix rekey`.
#
# `tailnetOrg = "-"`: the Tailscale API's name for the OAuth client's own
# tailnet, so each profile's API calls go to the tailnet its client belongs
# to without naming it.
#
# Profiles: `cslab` (CSLab's tailnet, which ank may join) and `leoank`
# (ank's own; its secrets are the ones ank_mesh uses, copied here under the
# anklab names). `defaultProfile` is `mkDefault "cslab"`; a machine picks
# another with `neusis.services.tailscale.defaultProfile`. Don't import it
# with `ank_mesh` or `cslab_mesh`: they define the same profiles.
#
# Config-only: the machine imports the tailscale module
# (`self.<nixos|darwin>Modules.tailscale`) and the secrets module; see
# ank_mesh.nix for the recipe. `--hostname` is the machine's own hostname.
{ ... }:
{
  flake.neusis.features.agnostic.anklab_mesh =
    { config, lib, ... }:
    let
      profiles = [
        "cslab"
        "leoank"
      ];
      secret = profile: kind: "${profile}Ts${kind}";
      kinds = [
        "AuthKey"
        "ClientId"
        "ClientSecret"
      ];
    in
    {
      age.secrets = lib.listToAttrs (
        lib.concatMap (
          p:
          map (
            k:
            lib.nameValuePair (secret p k) {
              rekeyFile = ../../secrets/anklab + "/${secret p k}.age";
            }
          ) kinds
        ) profiles
      );

      neusis.services.tailscale = {
        enable = true;
        defaultProfile = lib.mkDefault "cslab";
        profiles = lib.genAttrs profiles (p: {
          authKeyFile = config.age.secrets.${secret p "AuthKey"}.path;
          hostName = config.networking.hostName;
          ephemeral = false;
          forceHostName = true;
          tailnetOrg = "-";
          clientIdFile = config.age.secrets.${secret p "ClientId"}.path;
          clientSecretFile = config.age.secrets.${secret p "ClientSecret"}.path;
          disableKeyExpiry = true;
        });
      };
    };
}
