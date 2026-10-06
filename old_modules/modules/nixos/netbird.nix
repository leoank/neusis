# Adapted from https://gitlab.com/usmcamp0811/dotfiles/-/blob/fbb73911d38f5f4813544dde0b4840f187169150/modules/nixos/services/netbird/default.nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground;
# PIRs:
# 1. What ports must be open?
# 2. How to make Turn Server work correctly
let
  cfg = config.neusis.services.netbird;
in
{
  options.neusis.services.netbird = with types; {
    client = {
      enable = mkBoolOpt false "Enable Netbird Client Only";
    };
    server = {
      enable = mkBoolOpt false "Enable Netbird;";
      domain = mkOpt str "leoank.me" "Top level domain used for all theings";
      oidc-domain = mkOpt str "netbird.auth.${cfg.server.domain}" "Domain for Netbird to use";
      netbird-domain = mkOpt str "netbird.${cfg.server.domain}" "Netbird Domain";
      listen-addr = mkOpt str "0.0.0.0" "The Hostname/IP that NGINX will listen on.";
      port = mkOpt int 10031 "Port to use";
      turn-port = mkOpt int 3478 "TURN Port -- UDP";
      management-port = mkOpt int 33073 "Management Port -- gRPC";
      signal-port = mkOpt int 10000 "Signal Port -- TCP";
      metrics-port = mkOpt int 9092 "Metrics Port -- TCP";
      client-id = mkOpt str "cDngatAca7vzV61toEzBSmqQCu7Z8YuhiTFRJH3U" "Client ID";
    };

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/netbird"
        "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [
        "v1"
        "v2"
      ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf (cfg.server.enable || cfg.client.enable) {
    services.netbird = {
      enable = true;

      server = mkIf cfg.server.enable {
        enableNginx = lib.mkForce true;
        domain = cfg.server.netbird-domain;
        management = {
          enable = true;
          metricsPort = cfg.server.metrics-port;
          port = cfg.server.management-port;
          enableNginx = lib.mkForce true;
          oidcConfigEndpoint = "https://${cfg.server.oidc-domain}/application/o/netbird/.well-known/openid-configuration";
          domain = cfg.server.netbird-domain;
          turnDomain = "turn.${cfg.server.netbird-domain}";
          dnsDomain = "dns.${cfg.server.netbird-domain}";
          singleAccountModeDomain = cfg.server.netbird-domain;

          settings = {
            TURNConfig = {
              Turns = [
                {
                  Proto = "udp";
                  URI = "turn:turn.${cfg.server.netbird-domain}:${toString cfg.server.turn-port}";
                  Username = "netbird";
                  Password._secret = "/var/lib/netbird-mgmt/coturn_nb";
                }
              ];

              Secret._secret = "/var/lib/netbird-mgmt/turn";
            };

            DataStoreEncryptionKey = null;
            # TODO: Change to Postgres
            # StoreConfig = { Engine = "sqlite"; };

            HttpConfig = {
              AuthAudience = cfg.server.client-id;
              AuthUserIDClaim = "sub";
              AuthIssuer = "https://${cfg.server.oidc-domain}/application/o/netbird/";
              AuthKeysLocation = "https://${cfg.server.oidc-domain}/application/o/netbird/jwks/";
            };

            IdpManagerConfig = {
              ManagerType = "authentik";
              ClientConfig = {
                Issuer = "https://${cfg.server.oidc-domain}/application/o/netbird/";
                ClientID = cfg.server.client-id;
                TokenEndpoint = "https://${cfg.server.oidc-domain}/application/o/token/";
                ClientSecret = "";
              };
              ExtraConfig = {
                Password._secret = "/var/lib/netbird-mgmt/netbird_authentik_password";
                Username = "NetBird";
              };
            };
            PKCEAuthorizationFlow.ProviderConfig = {
              Audience = cfg.server.client-id;
              ClientID = cfg.server.client-id;
              ClientSecret = "";
              Scope = "openid profile email offline_access api";
              AuthorizationEndpoint = "https://${cfg.server.oidc-domain}/application/o/authorize/";
              TokenEndpoint = "https://${cfg.server.oidc-domain}/application/o/token/";
              RedirectURLs = [
                # "https://${cfg.server.netbird-domain}"
                "http://localhost:53000"
              ];
            };
          };
        };

        signal = {
          enable = true;
          port = cfg.server.signal-port;
          domain = cfg.server.netbird-domain;
          enableNginx = lib.mkForce true;
        };

        dashboard = {
          enable = true;
          enableNginx = true;
          domain = cfg.server.netbird-domain;
          managementServer = "https://${cfg.server.netbird-domain}";
          settings = {
            AUTH_AUTHORITY = "https://${cfg.server.oidc-domain}/application/o/netbird/";
            AUTH_SUPPORTED_SCOPES = "openid profile email offline_access api";
            AUTH_AUDIENCE = cfg.server.client-id;
            AUTH_CLIENT_ID = cfg.server.client-id;
            USE_AUTH0 = "false";
          };
        };

        coturn = {
          enable = true;
          passwordFile = "/var/lib/coturn/secret";
          domain = cfg.server.netbird-domain;
        };
      };
    };
    services.nginx.virtualHosts.${cfg.server.netbird-domain} = mkIf cfg.server.enable {
      listen = [
        {
          addr = cfg.server.listen-addr;
          port = cfg.server.port;
          ssl = false;
        }
      ];
    };

    systemd.services.netbirdSecrets = mkIf cfg.server.enable {
      description = "Set up Netbird Secrets with Correct Permissions";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        # Create necessary directories with correct permissions
        mkdir -p /var/lib/netbird/coturn /var/lib/coturn /var/lib/netbird-mgmt
        chmod 750 /var/lib/netbird /var/lib/coturn /var/lib/netbird-mgmt
        chown -R netbird:netbird /var/lib/netbird
        chown -R netbird:netbird /var/lib/netbird-mgmt
        chown -R turnserver:turnserver /var/lib/coturn

        # Set up coturn secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/coturn > /var/lib/coturn/secret
        chmod 640 /var/lib/coturn/secret
        chown turnserver:turnserver /var/lib/coturn/secret

        # Set up turn secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/turn > /var/lib/netbird-mgmt/turn
        chmod 640 /var/lib/netbird-mgmt/turn
        chown turnserver:netbird /var/lib/netbird-mgmt/turn

        # Set up coturn_nb secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/coturn > /var/lib/netbird-mgmt/coturn_nb
        chmod 640 /var/lib/netbird-mgmt/coturn_nb
        chown netbird:netbird /var/lib/netbird-mgmt/coturn_nb

        # Set up netbird_authentik_password secret
        ${pkgs.coreutils}/bin/cat /tmp/detsys-vault/netbird_authentik_password > /var/lib/netbird-mgmt/netbird_authentik_password
        chmod 600 /var/lib/netbird-mgmt/netbird_authentik_password
        chown netbird:netbird /var/lib/netbird-mgmt/netbird_authentik_password
      '';

      wantedBy = [ "multi-user.target" ];
      before = [
        "netbird-management.service"
        "netbird-signal.service"
        "netbird-dashboard.service"
        "coturn.service"
      ];
    };
    users.users.netbird = {
      name = "netbird";
      group = "netbird";
      isSystemUser = true;
      extraGroups = [ "turnserver" ];
    };
    users.groups.netbird = { };

    campground.services.vault-agent.services = {
      netbirdSecrets = {
        settings = {
          vault.address = cfg.vault-address;
          auto_auth = {
            method = [
              {
                type = "approle";
                config = {
                  role_id_file_path = cfg.role-id;
                  secret_id_file_path = cfg.secret-id;
                  remove_secret_id_file_after_reading = false;
                };
              }
            ];
          };
        };
        secrets = {
          file = {
            files = {
              "netbird_authentik_password" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.authentik_user_password  }}{{ else }}{{ .Data.data.authentik_user_password }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "coturn" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.coturn }}{{ else }}{{ .Data.data.coturn }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
              "turn" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.turn }}{{ else }}{{ .Data.data.turn }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
            };
          };
        };
      };
    };
  };
}
