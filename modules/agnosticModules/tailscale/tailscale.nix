# Neusis tailscale system module — agnostic (NixOS + nix-darwin).
#
# Re-exported to `self.nixosModules.tailscale` / `self.darwinModules.tailscale`
# via re-export-all.nix. Runs ONE system-wide tailscaled at a time, but lets
# you declare several named *profiles* (distinct tailnet logins) and switch
# between them at runtime. Exactly one profile is active at any moment — this
# is Tailscale's built-in "fast user switching" (`tailscale switch`), not
# multiple daemons. For genuinely concurrent tailnets, see the future tsnet
# application-proxy path (docs/tailmux-proxy-spec.md).
#
# Configure via `neusis.services.tailscale`:
#
#   imports = [ self.darwinModules.tailscale ];
#   neusis.services.tailscale = {
#     enable = true;
#     defaultProfile = "leoank";
#     profiles.leoank = {
#       authKeyFile = config.age.secrets.tsAuthKeyLeoank.path;
#       hostName = "rogue";
#       forceHostName = true;
#       tailnetOrg = "leoank.github";
#       clientIdFile = config.age.secrets.tsClientId.path;
#       clientSecretFile = config.age.secrets.tsClientSecret.path;
#       disableKeyExpiry = true;
#     };
#     profiles.cslab.authKeyFile = config.age.secrets.tsAuthKeyCslab.path;
#   };
#
# Ported verbatim from the old `neusis.tailscale` (modules/nixos/tailscale.nix):
# persistent/ephemeral auth keys, custom `--hostname`, OAuth force-claim
# hostname, OAuth disable-key-expiry. The old `isUserSpace` flag was dead code
# (declared, never wired) and is intentionally dropped — a single system daemon
# uses the kernel tun; userspace networking belongs to the tsnet path.
#
# HOW ONE MODULE STAYS AGNOSTIC despite platform-only options: the autoconnect
# daemon needs `launchd.daemons` on Darwin and `systemd.services` on NixOS —
# top-level option keys that don't exist on the other platform. `lib.mkIf
# <plat>` still registers the option PATH (errors "option does not exist" on
# the other platform), and `lib.optionalAttrs pkgs.stdenv.isLinux` gates
# presence eagerly and dead-locks on `pkgs` (infinite recursion, since deciding
# a top-level key forces the nixpkgs instantiation). The escape: dispatch on
# `options ? launchd` / `options ? systemd` — a predicate read from the OPTIONS
# set, which is available without forcing `pkgs`. `optionalAttrs` on that
# predicate omits the foreign key entirely. nix-darwin `services.tailscale`
# only runs `tailscaled` (no auth), so the Darwin branch adds a launchd
# bring-up; NixOS `services.tailscale` supplies the daemon + firewall and gets
# a systemd oneshot (kept uniform with Darwin rather than using nixpkgs'
# `authKeyFile` autoconnect, so the nickname / force-claim sequencing matches).
{ ... }:
let
  # OAuth helper scripts shipped next to this module (OS-agnostic curl/jq).
  forceClaimScript = ./force-claim.sh;
  disableExpiryScript = ./disable-key-expiry.sh;

  mkProfileType =
    lib:
    lib.types.submodule {
      options = {
        authKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Runtime path to a file holding this profile's tailscale auth key
            (typically an agenix secret `.path`). Passed to the CLI as
            `--auth-key file:<path>`, so it is read at connect time and never
            embedded in the store. `null` ⇒ interactive login.
          '';
        };
        hostName = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Device hostname advertised on this profile's tailnet (`--hostname`).";
        };
        extraUpFlags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "--ssh"
            "--accept-routes"
          ];
          description = "Extra flags applied via `tailscale up` while this profile is active.";
        };
        ephemeral = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Informational: documents that `authKeyFile` points at an ephemeral
            key (successor to the old `isPersistent` flag). The key file is
            authoritative; this changes no behaviour on its own.
          '';
        };
        forceHostName = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            After connecting, force-claim the exact `hostName` on this tailnet
            via the OAuth API: conflicting devices are renamed to
            `<name>-old-<timestamp>` (never deleted), then this device takes
            the exact name. Requires `hostName`, `tailnetOrg`, `clientIdFile`,
            `clientSecretFile`.
          '';
        };
        tailnetOrg = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "leoank.github";
          description = "Tailnet organisation, used by the force-claim / disable-key-expiry OAuth calls.";
        };
        clientIdFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Runtime path to the OAuth client-ID file.";
        };
        clientSecretFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Runtime path to the OAuth client-secret file.";
        };
        disableKeyExpiry = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            After connecting, mark this device's key non-expiring via the OAuth
            API. Requires `tailnetOrg`, `clientIdFile`, `clientSecretFile`.
          '';
        };
      };
    };

  # `neusis-ts-<name>`: make `<name>` the active system profile — creating it
  # from its auth key on first use — then apply its preferences and any OAuth
  # post-connect steps. Reused verbatim as the boot autoconnect for the
  # default profile.
  mkProfileScript =
    pkgs: lib: tsPackage: name: profile:
    let
      upFlags =
        profile.extraUpFlags
        ++ lib.optionals (profile.hostName != null) [
          "--hostname"
          profile.hostName
        ];
    in
    pkgs.writeShellApplication {
      name = "neusis-ts-${name}";
      runtimeInputs = [
        tsPackage
        pkgs.jq
        pkgs.curl
        pkgs.coreutils
        pkgs.bash
      ];
      text = ''
        # Make "${name}" the active system-wide tailscale profile.
        # Only one profile is active at a time (Tailscale fast switching).

        # Wait for tailscaled to become reachable (boot ordering is
        # best-effort, especially under Darwin launchd).
        n=0
        while [ "$n" -lt 60 ]; do
          if tailscale status --json >/dev/null 2>&1; then break; fi
          n=$((n + 1))
          sleep 1
        done

        if tailscale switch "${name}" >/dev/null 2>&1; then
          echo "[neusis-ts] switched to existing profile: ${name}"
        else
          echo "[neusis-ts] creating/authenticating profile: ${name}"
          # `login` is the add-account verb; with a different tailnet's key it
          # creates a fresh profile instead of re-auth'ing the current one.
          tailscale login ${
            lib.optionalString (profile.authKeyFile != null) "--auth-key file:${profile.authKeyFile}"
          } ${lib.optionalString (profile.hostName != null) "--hostname ${profile.hostName}"}
          # Stable nickname so future `tailscale switch ${name}` is instant.
          tailscale set --nickname "${name}" || true
        fi

        # Apply preferences (idempotent).
        tailscale up ${lib.escapeShellArgs upFlags}
        ${lib.optionalString profile.forceHostName ''

          # Force-claim the exact hostname on this tailnet (OAuth API).
          TS_CLIENT_ID_FILE=${profile.clientIdFile} \
          TS_CLIENT_SECRET_FILE=${profile.clientSecretFile} \
          TAILNET_ORG=${profile.tailnetOrg} \
          NODE_NAME=${profile.hostName} \
            bash ${forceClaimScript}
        ''}
        ${lib.optionalString profile.disableKeyExpiry ''

          # Disable key expiry for this device (OAuth API).
          TS_CLIENT_ID_FILE=${profile.clientIdFile} \
          TS_CLIENT_SECRET_FILE=${profile.clientSecretFile} \
            bash ${disableExpiryScript}
        ''}
      '';
    };
in
{
  flake.agnosticModules.tailscale =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.services.tailscale;

      # Platform discriminators read from the OPTIONS set (NOT `pkgs`), so they
      # don't force nixpkgs instantiation and are safe to gate top-level option
      # keys with. nix-darwin declares `launchd`; NixOS declares `systemd`.
      isDarwin = options ? launchd;
      isLinux = options ? systemd;

      scriptFor = name: profile: mkProfileScript pkgs lib cfg.package name profile;
      defaultScript = mkProfileScript pkgs lib cfg.package cfg.defaultProfile cfg.profiles.${cfg.defaultProfile};
    in
    {
      options.neusis.services.tailscale = {
        enable = lib.mkEnableOption "neusis-managed system tailscale (single active tailnet, switchable profiles)";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.tailscale;
          defaultText = lib.literalExpression "pkgs.tailscale";
          description = "The tailscale package providing the daemon + CLI.";
        };

        profiles = lib.mkOption {
          type = lib.types.attrsOf (mkProfileType lib);
          default = { };
          description = ''
            Named tailnet profiles. Each is a distinct login (its own
            account/tailnet); only one is active system-wide at a time. Each
            profile gets a `neusis-ts-<name>` command on PATH to switch to it.
          '';
        };

        defaultProfile = lib.mkOption {
          type = lib.types.str;
          description = ''
            Name of the profile brought up automatically at boot (must be a key
            of `profiles`). Switch away at runtime with `neusis-ts-<other>` /
            `tailscale switch <other>`.
          '';
        };

        autoConnect = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Bring up `defaultProfile` automatically at boot.";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "NixOS only: open the tailscale UDP port in the firewall.";
        };

        useRoutingFeatures = lib.mkOption {
          type = lib.types.enum [
            "none"
            "client"
            "server"
            "both"
          ];
          default = "client";
          description = ''
            NixOS only: forwarded to nixpkgs `services.tailscale.useRoutingFeatures`
            (reverse-path / IP-forward sysctls for exit-node & subnet-router use).
          '';
        };

        overrideLocalDns = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Darwin only: forwarded to nix-darwin `services.tailscale.overrideLocalDns`
            (pins 100.100.100.100 as the sole resolver).
          '';
        };
      };

      config = lib.mkMerge [
        # Cross-platform core (all keys exist on both). `services.tailscale`
        # exists on both platforms; its platform-only SUB-options are gated
        # deep (a value-level `optionalAttrs`, safe because the `services` key
        # is present unconditionally).
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = (!cfg.autoConnect) || (cfg.profiles ? ${cfg.defaultProfile});
              message = "neusis.services.tailscale.defaultProfile '${cfg.defaultProfile}' is not defined in profiles.";
            }
          ];
          environment.systemPackages = [ cfg.package ] ++ lib.mapAttrsToList scriptFor cfg.profiles;

          services.tailscale = {
            enable = true;
            package = cfg.package;
          }
          // lib.optionalAttrs isLinux {
            openFirewall = cfg.openFirewall;
            useRoutingFeatures = cfg.useRoutingFeatures;
          }
          // lib.optionalAttrs isDarwin {
            overrideLocalDns = cfg.overrideLocalDns;
          };
        })

        # NixOS autoconnect: systemd oneshot after tailscaled. `optionalAttrs
        # isLinux` omits `systemd` entirely on Darwin.
        (lib.optionalAttrs isLinux {
          systemd.services.neusis-tailscale-autoconnect = lib.mkIf (cfg.enable && cfg.autoConnect) {
            description = "Bring up the default neusis tailscale profile (${cfg.defaultProfile})";
            after = [
              "tailscaled.service"
              "network-online.target"
            ];
            wants = [
              "tailscaled.service"
              "network-online.target"
            ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = lib.getExe defaultScript;
            };
          };
        })

        # Darwin autoconnect: launchd daemon (nix-darwin never `up`s). KeepAlive
        # SuccessfulExit=false ⇒ retry until it connects, then stop.
        # `optionalAttrs isDarwin` omits `launchd` entirely on NixOS.
        (lib.optionalAttrs isDarwin {
          launchd.daemons.neusis-tailscale-autoconnect = lib.mkIf (cfg.enable && cfg.autoConnect) {
            serviceConfig = {
              Label = "org.neusis.tailscale-autoconnect";
              ProgramArguments = [ (lib.getExe defaultScript) ];
              RunAtLoad = true;
              KeepAlive = {
                SuccessfulExit = false;
              };
            };
          };
        })
      ];
    };
}
