# Neusis mesh — the tailnets ank can join through anklab (agnostic feature,
# config-only). Replaces `cslab_mesh`, one machine at a time.
#
# Every network is a tailscale profile named after it, with secrets in
# secrets/anklab/: `<profile>TsAuthKey` to join, and an OAuth client of that
# tailnet for the hostname force-claim and the non-expiring key. Where the
# tailnet has a client limited to devices:core, `<profile>DeviceTsClientId` /
# `<profile>DeviceTsClientSecret`, the machines use that one; the
# all-permission `<profile>TsClientId` / `<profile>TsClientSecret` are for
# rogue only (rogue.nix). A tailnet with a single client (shntnu) uses
# `<profile>TsClient*`. Adding a network = its secrets + an entry in
# `profiles` below. Edit with `agenix edit modules/secrets/anklab/<name>.age`,
# then `agenix rekey`.
#
# `tailnetOrg = "-"`: the Tailscale API's name for the OAuth client's own
# tailnet, so each profile's API calls go to the tailnet its client belongs
# to without naming it.
#
# Profiles, named after their tailnets: `runxi` (runxi-shen.github, CSLab's
# current tailnet, which ank may join; the default), `leoank` (ank's own,
# also where the saarthi hub and nodes meet) and `shntnu` (shntnu.github,
# CSLab's previous tailnet, kept while machines move off it). The leoank and
# shntnu secrets are encrypted copies of ank_mesh's and cslab_mesh's.
# `defaultProfile` is `mkDefault "runxi"`; a machine picks another with
# `neusis.services.tailscale.defaultProfile`. Don't import it with `ank_mesh`
# or `cslab_mesh`.
#
# A client secret that is a Tailscale API access token (`tskey-api-…`) is used
# as the API token directly; otherwise it is an OAuth client secret,
# exchanged with its client id for a token.
#
# Config-only: the machine imports the tailscale module
# (`self.<nixos|darwin>Modules.tailscale`) and the secrets module; see
# ank_mesh.nix for the recipe. `--hostname` is the machine's own hostname.
{ ... }:
{
  flake.neusis.features.agnostic.anklab_mesh =
    { config, lib, ... }:
    let
      # profile -> the prefix of the OAuth client the scripts use: "Device" for a
      # devices:core-only client, "" for the tailnet's only client.
      profiles = {
        runxi = "Device";
        leoank = "Device";
        shntnu = "";
      };
      names = p: {
        authKey = "${p}TsAuthKey";
        clientId = "${p}${profiles.${p}}TsClientId";
        clientSecret = "${p}${profiles.${p}}TsClientSecret";
      };
    in
    {
      age.secrets = lib.listToAttrs (
        lib.concatMap (
          p:
          map (n: lib.nameValuePair n { rekeyFile = ../../secrets/anklab + "/${n}.age"; }) (
            builtins.attrValues (names p)
          )
        ) (builtins.attrNames profiles)
      );

      neusis.services.tailscale = {
        enable = true;
        defaultProfile = lib.mkDefault "runxi";
        profiles = lib.mapAttrs (
          p: _:
          let
            n = names p;
          in
          {
            authKeyFile = config.age.secrets.${n.authKey}.path;
            hostName = config.networking.hostName;
            ephemeral = false;
            forceHostName = true;
            tailnetOrg = "-";
            clientIdFile = config.age.secrets.${n.clientId}.path;
            clientSecretFile = config.age.secrets.${n.clientSecret}.path;
            disableKeyExpiry = true;
          }
        ) profiles;
      };
    };
}
