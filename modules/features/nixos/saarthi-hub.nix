# Neusis feature: the saarthi hub, wired for ank's fleet (NixOS).
#
# The hub's module comes from the saarthi flake, its source of truth (saarthi
# ADR-0041): a machine imports `inputs.saarthi.nixosModules.saarthi-hub` (the
# service) and `self.neusis.features.nixos.saarthi-hub` (this), and needs the
# secrets service enabled (for agenix) — see machines/ghost001.nix. This feature
# adds what is the fleet's own: the data volume, the agenix token secrets, and a
# self-hosted ntfy the hub pushes through.
#
# Secrets (edit with `agenix edit modules/secrets/ank/<name>.age`, then
# `agenix rekey`):
#   saarthiNodeTokens    file of `<node name> <token>` lines
#   saarthiClientTokens  file of `<client name> <token>` lines
#
# ntfy is self-hosted and reachable over the tailnet only (its port is not
# opened on the host firewall or the OCI security list). The hub posts to the
# `saarthi` topic locally; the phone registers UnifiedPush endpoints against the
# same server.
{ ... }:
{
  # The saarthi flake: the hub and node modules and the `saarthi` and
  # `saarthi-hub` binaries. ank's node bundle and the agent harness read it too;
  # it is declared once here.
  flake-file.inputs.saarthi = {
    url = "github:leoank/saarthi";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  flake.neusis.features.nixos.saarthi-hub =
    { config, pkgs, ... }:
    let
      dataDir = "/srv/saarthi";
      # Before the rename the hub was rc2s2-hub with its record in /srv/rc2s2.
      # On the first start after the switch (which has stopped the old unit),
      # copy that record over, as root, and give it to the new user; the old
      # directory stays as a backup. A no-op once hub.db exists here.
      migrate = pkgs.writeShellScript "saarthi-hub-migrate" ''
        set -eu
        old=/srv/rc2s2
        new=${dataDir}
        if [ -e "$old/hub.db" ] && [ ! -e "$new/hub.db" ]; then
          install -d -m 0750 -o saarthi-hub -g saarthi-hub "$new"
          cp -p "$old"/hub.db* "$new"/
          chown saarthi-hub:saarthi-hub "$new"/hub.db*
          echo "saarthi-hub: copied the hub record from $old to $new"
        fi
      '';
    in
    {
      age.secrets.saarthiNodeTokens = {
        rekeyFile = ../../secrets/ank/saarthiNodeTokens.age;
        owner = "saarthi-hub";
        group = "saarthi-hub";
      };
      age.secrets.saarthiClientTokens = {
        rekeyFile = ../../secrets/ank/saarthiClientTokens.age;
        owner = "saarthi-hub";
        group = "saarthi-hub";
      };

      services.saarthi-hub = {
        enable = true;
        # Persist the SQLite record on the data volume (survives
        # reprovisioning); reachable over the tailnet only.
        inherit dataDir;
        listen = "0.0.0.0:7700";
        openFirewall = false;
        nodeTokensFile = config.age.secrets.saarthiNodeTokens.path;
        clientTokensFile = config.age.secrets.saarthiClientTokens.path;
        ntfy = "http://127.0.0.1:2586/saarthi";
      };

      # `+`: runs as root, outside the service's sandbox, before the hub starts.
      systemd.services.saarthi-hub.serviceConfig.ExecStartPre = [ "+${migrate}" ];

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
