# Invariants of the real `ghost001` host (first NixOS host, on OCI) and
# the `ank@ghost001` home: identity, the pre-generated host key, the
# oci-guest layout matching the base image, services, users, policy.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = self.nixosConfigurations.ghost001.config;
      home = self.homeConfigurations."ank@ghost001".config;
      m = self.neusis.machines.ghost001;
      base = (self.neusis.lib.cloud.mkOciBaseImage { system = "aarch64-linux"; }).nixosConfig;

      # "ssh-ed25519 AAAA… comment" → "ssh-ed25519 AAAA…"
      keyOf = s: lib.concatStringsSep " " (lib.take 2 (lib.splitString " " (lib.removeSuffix "\n" s)));
      bootstrapPub = keyOf (builtins.readFile ../../secrets/bootstrap/ghost001/etc/ssh/ssh_host_ed25519_key.pub);
    in
    {
      tests.machine-ghost001 = {
        test-identity = {
          expr = {
            host = cfg.networking.hostName;
            platform = cfg.nixpkgs.hostPlatform.system;
            hostPubkey = cfg.neusis.services.secrets.hostPubkey == m.hostPubkey;
            # the key pushed at bootstrap is the one agenix rekeys for
            bootstrapKeyMatches = bootstrapPub == m.hostPubkey;
            rekeyDir = lib.hasSuffix "/modules/secrets/rekeyed/ghost001" (toString cfg.age.rekey.localStorageDir);
          };
          expected = {
            host = "ghost001";
            platform = "aarch64-linux";
            hostPubkey = true;
            bootstrapKeyMatches = true;
            rekeyDir = true;
          };
        };

        # Base image → host `nixos-rebuild switch` keeps the disk layout
        # and bootloader (the invariant from spec §4.4).
        test-disk-layout-matches-the-base-image = {
          expr =
            let
              layout = c: {
                root = c.fileSystems."/";
                esp = c.fileSystems."/boot".device;
                grub = {
                  inherit (c.boot.loader.grub) device efiSupport efiInstallAsRemovable;
                };
                grow = c.boot.growPartition;
              };
            in
            {
              same = layout cfg == layout base;
              # host-only: no IMDS key fetching after bootstrap
              imds = cfg.systemd.services ? fetch-ssh-keys;
            };
          expected = {
            same = true;
            imds = false;
          };
        };

        # Application state lives on the stack's data volume, by label,
        # and its absence must not block boot.
        test-data-volume-on-srv = {
          expr = {
            device = cfg.fileSystems."/srv".device;
            fsType = cfg.fileSystems."/srv".fsType;
            nofail = builtins.elem "nofail" cfg.fileSystems."/srv".options;
          };
          expected = {
            device = "/dev/disk/by-label/data";
            fsType = "ext4";
            nofail = true;
          };
        };

        test-state-versions-are-pinned = {
          expr = {
            system = cfg.system.stateVersion;
            homeIntegrated = cfg.home-manager.users.ank.home.stateVersion;
            homeStandalone = home.home.stateVersion;
          };
          expected = {
            system = "26.05";
            homeIntegrated = "25.11";
            homeStandalone = "25.11";
          };
        };

        test-users-and-homes = {
          expr = {
            hmUsers = builtins.attrNames cfg.home-manager.users;
            ankShell = lib.getName cfg.users.users.ank.shell;
            ankWheel = builtins.elem "wheel" cfg.users.users.ank.extraGroups;
            ankPassword = cfg.users.users.ank.hashedPasswordFile == cfg.age.secrets.commonInitialHashedPassword.path;
            rootKeyOnly = cfg.services.openssh.settings.PermitRootLogin;
            standaloneHome = home.home.homeDirectory;
            kalam = t.hasPkg "nixvim" home.home.packages;
            neusisCli = t.hasPkg "neusis" home.home.packages;
          };
          expected = {
            hmUsers = [ "ank" ];
            ankShell = "zsh";
            ankWheel = true;
            ankPassword = true;
            rootKeyOnly = "prohibit-password";
            standaloneHome = "/home/ank";
            kalam = true;
            neusisCli = true;
          };
        };

        test-services = {
          expr = {
            tailscale = cfg.neusis.services.tailscale.enable;
            defaultMesh = cfg.neusis.services.tailscale.defaultProfile;
            buildServer = cfg.neusis.services.build-server.enable;
            # offloads to the lab builders, never to itself
            buildsOffloadTo = map (b: b.hostName) cfg.nix.buildMachines;
            sshd = cfg.services.openssh.enable;
            flakes = lib.hasInfix "flakes" cfg.nix.extraOptions;
            # cloudflared connector fed by the agenix tunnel token
            tunnel = cfg.neusis.services.cloudflare-tunnel.enable;
            tunnelToken = cfg.neusis.services.cloudflare-tunnel.tokenFile == cfg.age.secrets.cfTunnelToken.path;
          };
          expected = {
            tailscale = true;
            defaultMesh = "cslab";
            buildServer = true;
            buildsOffloadTo = [
              "spirit"
              "oppy"
              "rogue"
            ];
            sshd = true;
            flakes = true;
            tunnel = true;
            tunnelToken = true;
          };
        };

        # ank's saarthi node on ghost001: a user service pointed at the hub on the same
        # host, its token a system secret owned by ank, kept running by linger.
        test-saarthi-node = {
          expr =
            let
              s = home.systemd.user.services.saarthi-node;
              line = lib.concatStringsSep " " (lib.toList s.Service.ExecStart);
            in
            {
              hub = lib.hasInfix "--hub http://127.0.0.1:7700" line;
              name = lib.hasInfix "--name ghost001" line;
              token = lib.hasInfix "--token-file /run/agenix/saarthiGhost001NodeToken" line;
              tokenOwner = cfg.age.secrets.saarthiGhost001NodeToken.owner;
              linger = cfg.users.users.ank.linger;
              # saarthi refuses to start without its spawn root
              spawnRoot = lib.elem "d /home/ank/workspace 0755 ank users -" cfg.systemd.tmpfiles.rules;
              claude = home.programs.claude-code.enable;
            };
          expected = {
            hub = true;
            name = true;
            token = true;
            tokenOwner = "ank";
            linger = true;
            spawnRoot = true;
            claude = true;
          };
        };

        # The saarthi hub records on the data volume and pushes through a
        # self-hosted ntfy, reachable over the tailnet only.
        test-saarthi-hub = {
          expr =
            let
              e = cfg.systemd.services.saarthi-hub.serviceConfig.ExecStart;
            in
            {
              hub = cfg.services.saarthi-hub.enable;
              oldHub = cfg.systemd.services ? rc2s2-hub;
              migrates = cfg.systemd.services.saarthi-hub.serviceConfig.ExecStartPre != [ ];
              dbOnSrv = lib.hasInfix "--db /srv/saarthi/hub.db" e;
              tokensFromAgenix =
                lib.hasInfix "--node-tokens ${cfg.age.secrets.saarthiNodeTokens.path}" e
                && lib.hasInfix "--client-tokens ${cfg.age.secrets.saarthiClientTokens.path}" e;
              ntfy = cfg.services.ntfy-sh.enable;
              ntfyLocalTopic = lib.hasInfix "--ntfy http://127.0.0.1:2586/saarthi" e;
              claudeTokens = lib.hasInfix "--claude-tokens ${cfg.age.secrets.saarthiClaudeTokens.path}" e;
              # Neither the hub nor ntfy opens a host port: tailnet only.
              noOpenPorts =
                !(builtins.elem 7700 (cfg.networking.firewall.allowedTCPPorts or [ ]))
                && !(builtins.elem 2586 (cfg.networking.firewall.allowedTCPPorts or [ ]));
            };
          expected = {
            hub = true;
            oldHub = false;
            migrates = true;
            dbOnSrv = true;
            tokensFromAgenix = true;
            ntfy = true;
            ntfyLocalTopic = true;
            claudeTokens = true;
            noOpenPorts = true;
          };
        };

        # Enrolled in auto-updates in the stable group: comin polls
        # deploy/stable (a day behind rogue's canary) and testing-ghost001,
        # trusts only the registry signers, emails failures through the
        # notify secret, and a manual switch first runs the switch check.
        test-auto-update = {
          expr = {
            inherit (cfg.services.comin) enable;
            remotes = map (r: {
              inherit (r) url;
              branch = r.branches.main.name;
              testing = r.branches.testing.name;
              period = r.poller.period;
            }) cfg.services.comin.remotes;
            signers = cfg.services.comin.sshAllowedSignersPath != null;
            notify = cfg.neusis.services.auto-update.notify.environmentFile;
            emailTo = cfg.neusis.services.auto-update.notify.emailTo;
            switchCheck = cfg.system.preSwitchChecks ? neusis-auto-update;
          };
          expected = {
            enable = true;
            remotes = [
              {
                url = "https://github.com/leoank/neusis.git";
                branch = "deploy/stable";
                testing = "testing-ghost001";
                period = 60;
              }
            ];
            signers = true;
            notify = "/run/agenix/autoUpdateNotify";
            emailTo = [ "leoank98@gmail.com" ];
            switchCheck = true;
          };
        };

        test-no-failed-assertions = {
          expr = {
            system = t.failedAssertions cfg;
            home = t.failedAssertions home;
          };
          expected = {
            system = [ ];
            home = [ ];
          };
        };
      };
    };
}
