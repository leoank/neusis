# Neusis feature: the rc2s2 hub, wired for ank's fleet (NixOS).
#
# Turns on `neusis.services.rc2s2-hub` with the data volume, the agenix
# token secrets, and a self-hosted ntfy the hub pushes through. A machine
# that wants the hub imports `self.nixosModules.rc2s2-hub` (the service) and
# `self.neusis.features.nixos.rc2s2-hub` (this), and needs the secrets
# service enabled (for agenix) — see machines/ghost001.nix.
#
# Secrets (edit with `agenix edit modules/secrets/ank/<name>.age`, then
# `agenix rekey`):
#   rc2s2NodeTokens    file of `<node name> <token>` lines
#   rc2s2ClientTokens  file of `<client name> <token>` lines
#
# ntfy is self-hosted and reachable over the tailnet only (its port is not
# opened on the host firewall or the OCI security list). The hub posts to
# the `rc2s2` topic locally; the phone subscribes to that topic and/or
# registers a UnifiedPush endpoint against the same server (ADR-0026).
{ ... }:
{
  flake.neusis.features.nixos.rc2s2-hub =
    { config, ... }:
    {
      age.secrets.rc2s2NodeTokens = {
        rekeyFile = ../../secrets/ank/rc2s2NodeTokens.age;
        owner = "rc2s2-hub";
        group = "rc2s2-hub";
      };
      age.secrets.rc2s2ClientTokens = {
        rekeyFile = ../../secrets/ank/rc2s2ClientTokens.age;
        owner = "rc2s2-hub";
        group = "rc2s2-hub";
      };

      neusis.services.rc2s2-hub = {
        enable = true;
        # Persist the SQLite record on the data volume (survives
        # reprovisioning); reachable over the tailnet only.
        dataDir = "/srv/rc2s2";
        listen = "0.0.0.0:7700";
        openFirewall = false;
        nodeTokensFile = config.age.secrets.rc2s2NodeTokens.path;
        clientTokensFile = config.age.secrets.rc2s2ClientTokens.path;
        ntfy = "http://127.0.0.1:2586/rc2s2";
      };

      # Self-hosted ntfy for push. base-url is the tailnet name so the
      # phone can register UnifiedPush endpoints and subscribe; no auth,
      # single operator on a private tailnet.
      services.ntfy-sh = {
        enable = true;
        settings = {
          base-url = "http://ghost001:2586";
          listen-http = ":2586";
          behind-proxy = false;
          auth-default-access = "read-write";
        };
      };
    };
}
