{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.neusis.services.monitoring;

  mkAlloyConfig =
    prometheusPort: secret:
    pkgs.writeText "config.alloy" ''
          prometheus.scrape "metrics_hosted_prometheus_node" {
        targets = [{
          __address__ = "localhost:${toString prometheusPort}",
        }]
        forward_to = [prometheus.remote_write.metrics_hosted_prometheus.receiver]
        job_name   = "node"
      }

      local.file "alloy_prometheus_password" {
        filename = "${secret.path}"
        is_secret = true
      }

      prometheus.remote_write "metrics_hosted_prometheus" {
         endpoint {
            name = "hosted-prometheus"
            url  = "https://prometheus-prod-56-prod-us-east-2.grafana.net/api/prom/push"
          
            basic_auth {
              username = "2660759"
              password = local.file.alloy_prometheus_password.content
            }
         }
      }

    '';
  grafanaDashboardSource = pkgs.fetchFromGitHub {
    owner = "rfrail3";
    repo = "grafana-dashboards";
    rev = "fb8ab3ec1444622f76ffc64162e193623e082062";
    sha256 = "sha256-33Fy5f3DhWqMQQzpHkdezLUrXiWku/HLH/DmuuZ293c=";
  };

  nvidiaDashboardSource = pkgs.fetchFromGitHub {
    owner = "utkuozdemir";
    repo = "nvidia_gpu_exporter";
    rev = "ca6b809235a8b4ed8e92380733104c90be9e8240";
    sha256 = "sha256-Yh0iTQjV1oSwVmCIAdt7svG9MrKEewEIBBAPqUzsD88=";
  };

  ipmiExporterYAMLConfig = pkgs.writeText "ipmi_local.yml" ''
    modules:
      default:
        # Available collectors are bmc, bmc-watchdog, ipmi, chassis, dcmi, sel, sel-events and sm-lan-mode
        collectors:
          - ipmi
          # - sel
          # - sel-events
          # - sm-lan-mode
          # - bmc
          # - bmc-watchdog
          # - chassis
          # - dcmi
        collector_cmd:
          ipmi: /run/wrappers/bin/sudo
        #   sel: ${pkgs.sudo}/bin/sudo
        #   sel-events: ${pkgs.sudo}/bin/sudo
        #   sm-lan-mode: ${pkgs.sudo}/bin/sudo
        #   bmc: ${pkgs.sudo}/bin/sudo
        #   bmc-watchdog: ${pkgs.sudo}/bin/sudo
        #   chassis: ${pkgs.sudo}/bin/sudo
        #   dcmi: ${pkgs.sudo}/bin/sudo
        custom_args:
          ipmi:
            - ${pkgs.freeipmi}/bin/ipmimonitoring
  '';
in
{
  options = {
    neusis.services.monitoring = {
      enable = mkEnableOption "monitoring stack";

      prometheus = {
        enable = mkEnableOption "Prometheus monitoring" // {
          default = true;
        };
        port = mkOption {
          type = types.port;
          default = 9090;
          description = "Port for Prometheus web interface";
        };
        retention = mkOption {
          type = types.str;
          default = "3600d";
          description = "Data retention period";
        };
        domain = mkOption {
          type = types.nullOr types.str;
          default = "prometheus.${toString config.networking.hostName}";
          description = "Domain for Prometheus (optional)";
        };
      };

      grafana = {
        enable = mkEnableOption "Grafana dashboard" // {
          default = true;
        };
        port = mkOption {
          type = types.port;
          default = 3000;
          description = "Port for Grafana web interface";
        };
        domain = mkOption {
          type = types.nullOr types.str;
          default = "grafana.${toString config.networking.hostName}";
          description = "Domain for Grafana (optional)";
        };
      };

      alloy = {
        enable = mkEnableOption "Grafana Alloy" // {
          default = true;
        };
        port = mkOption {
          type = types.port;
          default = 9300;
          description = "Port for Grafana Alloy";
        };
      };

      nodeExporter = {
        enable = mkEnableOption "Node Exporter" // {
          default = true;
        };
        port = mkOption {
          type = types.port;
          default = 9100;
          description = "Port for Node Exporter";
        };
      };

      nvidiaExporter = {
        enable = mkEnableOption "Nvidia Exporter" // {
          default = true;
        };
        port = mkOption {
          type = types.port;
          default = 9835;
          description = "Port for Nvidia Exporter";
        };
      };

      zfsExporter = {
        enable = mkEnableOption "ZFS Exporter" // {
          default = true;
        };
        port = mkOption {
          type = types.port;
          default = 9134;
          description = "Port for ZFS Exporter";
        };
      };

      ipmiExporter = {
        enable = mkEnableOption "IPMI Exporter" // {
          default = false;
        };
        port = mkOption {
          type = types.port;
          default = 9290;
          description = "Port for IPMI Exporter";
        };
      };

      loki = {
        enable = mkEnableOption "Loki" // {
          default = true;
        };
        port = mkOption {
          type = types.port;
          default = 9194;
          description = "Port for Loki";
        };
        grpc_port = mkOption {
          type = types.port;
          default = 9195;
          description = "GRPC ort for Loki";
        };
      };

      nginx = {
        enable = mkEnableOption "nginx reverse proxy for Grafana" // {
          default = true;
        };
        serverName = mkOption {
          type = types.str;
          default = "grafana.${config.networking.hostName}";
          description = "Server name for nginx virtual host";
        };
        ssl = {
          enable = mkEnableOption "SSL/TLS for nginx";
          certificatePath = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to SSL certificate";
          };
          keyPath = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to SSL private key";
          };
        };
      };

      promtail = {
        enable = mkEnableOption "Promtail" // {
          default = true;
        };
        port = mkOption {
          type = types.port;
          default = 9196;
          description = "Port for Promtail";
        };

        grpc_port = mkOption {
          type = types.port;
          default = 9197;
          description = "GRPC ort for Promatail";
        };
      };

      alerts = {
        enable = mkEnableOption "Alertmanager";
        port = mkOption {
          type = types.port;
          default = 9093;
          description = "Port for Alertmanager";
        };
      };
    };
  };

  config = mkIf cfg.enable {

    age.secrets.alloy_key = mkIf cfg.alloy.enable {
      file = ../../secrets/oppy/alloy_key.age;
      # Required for alloy to read it dynamically
      mode = "770";
      owner = "prometheus";
      group = "prometheus";
    };

    services.prometheus = mkIf cfg.enable {
      enable = true;
      port = cfg.prometheus.port;
      retentionTime = cfg.prometheus.retention;
      remoteWrite = mkIf cfg.alloy.enable [
        {
          url = "https://prometheus-prod-56-prod-us-east-2.grafana.net/api/prom/push";
          basic_auth = {
            username = "2660759";
            password_file = config.age.secrets.alloy_key.path;
          };
        }

      ];
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.nodeExporter.port}" ];
            }
          ];
        }
        {
          job_name = "nvidia";
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.nvidiaExporter.port}" ];
            }
          ];
        }
        {
          job_name = "zfs";
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.zfsExporter.port}" ];
            }
          ];
        }
        {
          job_name = "ipmi";
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.ipmiExporter.port}" ];
            }
          ];
        }
        {
          job_name = "prometheus";
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.prometheus.port}" ];
            }
          ];
        }
      ];

      rules = [
        ''
          groups:
            - name: system
              rules:
                - alert: HighCPUUsage
                  expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High CPU usage detected"
                    description: "CPU usage is above 80% for more than 5 minutes"

                - alert: HighMemoryUsage
                  expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High memory usage detected"
                    description: "Memory usage is above 85% for more than 5 minutes"

                - alert: DiskSpaceLow
                  expr: (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"}) * 100 < 10
                  for: 5m
                  labels:
                    severity: critical
                  annotations:
                    summary: "Low disk space"
                    description: "Disk space is below 10% on {{ $labels.mountpoint }}"
        ''
      ];

      exporters.node = mkIf cfg.nodeExporter.enable {
        enable = true;
        port = cfg.nodeExporter.port;
        enabledCollectors = [
          "systemd"
          "processes"
          "network_route"
          "hwmon"
          "mountstats"
          "interrupts"
          "netdev"
          "filesystem"
          "diskstats"
          "cpu"
          "meminfo"
          "loadavg"
        ];
      };

      exporters.nvidia-gpu = mkIf cfg.nvidiaExporter.enable {
        enable = true;
        port = cfg.nvidiaExporter.port;
      };

      exporters.zfs = mkIf cfg.zfsExporter.enable {
        enable = true;
        port = cfg.zfsExporter.port;
      };

      exporters.ipmi = mkIf cfg.ipmiExporter.enable {
        enable = true;
        port = cfg.ipmiExporter.port;
        extraFlags = [ "--native-ipmi" ];
        #configFile = ipmiExporterYAMLConfig;
      };

      alertmanager = mkIf cfg.alerts.enable {
        enable = true;
        port = cfg.alerts.port;
        configuration = {
          global = {
            smtp_smarthost = "localhost:587";
            smtp_from = "alertmanager@localhost";
          };
          route = {
            group_by = [ "alertname" ];
            group_wait = "10s";
            group_interval = "10s";
            repeat_interval = "1h";
            receiver = "web.hook";
          };
          receivers = [
            {
              name = "web.hook";
              webhook_configs = [
                {
                  url = "http://localhost:5001/";
                }
              ];
            }
          ];
        };
      };
    };

    systemd.services.alloy.serviceConfig = mkIf cfg.alloy.enable {
      User = "ank";
      Group = "users";
    };

    services.alloy = mkIf cfg.alloy.enable {
      enable = false;
      configPath = (mkAlloyConfig cfg.prometheus.port config.age.secrets.alloy_key);
      extraFlags = [
        "--server.http.listen-addr=127.0.0.1:${toString cfg.alloy.port}"
      ];
    };

    services.loki = mkIf cfg.loki.enable {
      enable = true;
      configuration = {
        server = {
          http_listen_port = cfg.loki.port;
          grpc_listen_port = cfg.loki.grpc_port;
        };
        auth_enabled = false;
        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
          };

        };

        schema_config = {
          configs = [
            {
              from = "2025-06-06";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
        storage_config = {
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-shipper-active";
            cache_location = "/var/lib/loki/tsdb-shipper-cache";
            cache_ttl = "24h";
          };
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };
        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };
        compactor = {
          working_directory = "/var/lib/loki";
          compactor_ring = {
            instance_addr = "127.0.0.1";
            kvstore = {
              store = "inmemory";
            };
          };
        };
      };
    };

    services.promtail = mkIf cfg.promtail.enable {
      enable = true;
      configuration = {
        server = {
          http_listen_port = cfg.promtail.port;
          grpc_listen_port = cfg.promtail.grpc_port;
        };
        positions = {
          filename = "/tmp/positions.yaml";
        };
        clients = [
          {
            url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
          }
        ];
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = config.networking.hostName;
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }

        ];
      };

    };

    services.grafana = mkIf cfg.grafana.enable {
      enable = true;
      settings = {
        server = {
          http_port = cfg.grafana.port;
          domain = mkIf (cfg.grafana.domain != null) cfg.grafana.domain;
        };
        security = {
          admin_user = "admin";
          admin_password = "$__file{${pkgs.writeText "grafana-password" "admin"}}";
        };
      };

      provision = {
        enable = true;
        datasources.settings.datasources = mkIf cfg.prometheus.enable [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:${toString cfg.prometheus.port}";
            isDefault = true;
          }
          {
            name = "Loki";
            type = "loki";
            url = "http://localhost:${toString cfg.loki.port}";
          }
        ];

        dashboards.settings.providers = [
          {
            name = "default";
            orgId = 1;
            folder = "";
            type = "file";
            disableDeletion = false;
            updateIntervalSeconds = 10;
            allowUiUpdates = true;
            options.path = "/etc/grafana/dashboards";
          }
        ];
      };
    };

    # nginx configuration for Grafana
    services.nginx = mkIf cfg.nginx.enable {
      enable = true;
      virtualHosts."${cfg.nginx.serverName}" = {
        serverAliases = [
          "${cfg.grafana.domain}"
          "grafana.localhost"
        ];
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ]
        ++ (optionals cfg.nginx.ssl.enable [
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ]);

        forceSSL = cfg.nginx.ssl.enable;
        sslCertificate = mkIf cfg.nginx.ssl.enable cfg.nginx.ssl.certificatePath;
        sslCertificateKey = mkIf cfg.nginx.ssl.enable cfg.nginx.ssl.keyPath;

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.grafana.port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };

      virtualHosts."${cfg.prometheus.domain}" = {
        serverAliases = [
          "prometheus.localhost"
        ];
        listen = [
          {
            addr = "0.0.0.0";
            port = 80;
          }
        ]
        ++ (optionals cfg.nginx.ssl.enable [
          {
            addr = "0.0.0.0";
            port = 443;
            ssl = true;
          }
        ]);

        forceSSL = cfg.nginx.ssl.enable;
        sslCertificate = mkIf cfg.nginx.ssl.enable cfg.nginx.ssl.certificatePath;
        sslCertificateKey = mkIf cfg.nginx.ssl.enable cfg.nginx.ssl.keyPath;

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.prometheus.port}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };

    # System dashboards

    environment.etc = mkIf cfg.grafana.enable {
      "grafana/dashboards/node-exporter.json".source =
        "${grafanaDashboardSource}/prometheus/node-exporter-full.json";

      "grafana/dashboards/nvidia-exporter.json".source =
        "${nvidiaDashboardSource}/grafana/dashboard.json";
    };

    # Firewall configuration
    # networking.firewall.allowedTCPPorts = mkMerge [
    #   (mkIf cfg.prometheus.enable [ cfg.prometheus.port ])
    #   (mkIf cfg.grafana.enable [ cfg.grafana.port ])
    #   (mkIf cfg.nodeExporter.enable [ cfg.nodeExporter.port ])
    #   (mkIf cfg.alerts.enable [ cfg.alerts.port ])
    # ];

    # Systemd services for monitoring health
    # systemd.services.monitoring-health = mkIf cfg.enable {
    #   description = "Monitoring Stack Health Check";
    #   after = [ "network.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = pkgs.writeShellScript "monitoring-health" ''
    #       echo "Checking monitoring stack health..."
    #       ${optionalString cfg.prometheus.enable ''
    #         ${pkgs.curl}/bin/curl -f http://localhost:${toString cfg.prometheus.port}/-/healthy || exit 1
    #       ''}
    #       ${optionalString cfg.grafana.enable ''
    #         ${pkgs.curl}/bin/curl -f http://localhost:${toString cfg.grafana.port}/api/health || exit 1
    #       ''}
    #       echo "All monitoring services are healthy"
    #     '';
    #   };
    # };

    # systemd.timers.monitoring-health = mkIf cfg.enable {
    #   description = "Run monitoring health check";
    #   wantedBy = [ "timers.target" ];
    #   timerConfig = {
    #     OnCalendar = "hourly";
    #     Persistent = true;
    #   };
    # };
  };
}
