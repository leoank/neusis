# Pull-based auto-updates with comin (docs/auto-update-spec.md §9).
#
# Registers `flake.agnosticModules.auto-update`, re-exported as
# `nixosModules.auto-update` and `darwinModules.auto-update`. It
# configures comin but does not import it: comin's module is
# platform-specific and an import cannot depend on the platform, so the
# machine imports it, as with agenix:
#
#   imports = [
#     inputs.comin.<nixos|darwin>Modules.comin
#     self.<nixos|darwin>Modules.auto-update
#   ];
#   neusis.services.auto-update = {
#     enable = true;
#     url = "https://github.com/leoank/neusis.git";
#     branch = "deploy/canary";
#     signers = self.neusis.registry.signers.anklab;
#   };
#
# comin polls `branch`, deploys a new head only when it is signed by one
# of `signers`, and switches to `<kind>Configurations.<hostname>`. After
# every deployment the hook appends a JSON line to `logFile` (on darwin
# with the Homebrew delta) and, when `notify.environmentFile` is set,
# alerts through neusis-notify. The anklab policy (branch from the deploy
# group, signers, addresses) is `features.agnostic.auto-update`.
{ self, inputs, ... }:
{
  flake-file.inputs.comin = {
    url = "github:nlewo/comin/v0.14.0";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.agnosticModules.auto-update =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.services.auto-update;
      system = pkgs.stdenv.hostPlatform.system;

      # Homebrew's owner on darwin hosts that manage it: `brew` refuses to
      # run as root, and comin (and so the hook) runs as root.
      brewUser = if options ? homebrew && config.homebrew.enable then config.system.primaryUser else null;

      allowedSignersFile = pkgs.writeText "neusis-allowed-signers" (
        self.neusis.lib.autoUpdate.allowedSigners cfg.signers
      );

      hook = pkgs.writeShellApplication {
        name = "neusis-auto-update-hook";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
          pkgs.jq
          self.packages.${system}.neusis-notify
        ];
        text = ''
          log=${lib.escapeShellArg cfg.logFile}
          state=/var/lib/neusis-auto-update
          mkdir -p "$(dirname "$log")" "$state"

          status=''${COMIN_STATUS:-unknown}
          host=''${COMIN_HOSTNAME:-unknown}
          sha=''${COMIN_GIT_SHA:-}
          short=''${sha:0:12}

          # Homebrew delta since the previous deployment (darwin only).
          brew=null
          ${lib.optionalString (brewUser != null) ''
            now=$(mktemp)
            {
              /usr/bin/sudo -H -u ${lib.escapeShellArg brewUser} env HOMEBREW_NO_AUTO_UPDATE=1 \
                ${config.homebrew.prefix}/bin/brew list --formula --versions | sed 's/^/formula /'
              /usr/bin/sudo -H -u ${lib.escapeShellArg brewUser} env HOMEBREW_NO_AUTO_UPDATE=1 \
                ${config.homebrew.prefix}/bin/brew list --cask --versions | sed 's/^/cask /'
            } | sort > "$now" || true
            if [ -f "$state/brew.txt" ]; then
              brew=$(jq -n \
                --rawfile old "$state/brew.txt" --rawfile new "$now" \
                '($old | split("\n") | map(select(. != ""))) as $o
                 | ($new | split("\n") | map(select(. != ""))) as $n
                 | { added: ($n - $o), removed: ($o - $n) }')
            fi
            mv -f "$now" "$state/brew.txt"
          ''}

          jq -cn \
            --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --arg host "$host" \
            --arg status "$status" \
            --arg sha "$sha" \
            --arg ref "''${COMIN_GIT_REF:-}" \
            --arg generation "''${COMIN_GENERATION:-}" \
            --arg error "''${COMIN_ERROR_MSG:-}" \
            --argjson brew "$brew" \
            '{ time: $time, host: $host, status: $status, sha: $sha, ref: $ref,
               generation: $generation, error: $error, brew: $brew }' >> "$log"

          ${lib.optionalString (cfg.notify.environmentFile != null) ''
            export NTFY_URL=${lib.escapeShellArg cfg.notify.ntfyUrl}
            export ALERT_FROM=${lib.escapeShellArg (toString cfg.notify.emailFrom)}
            export ALERT_TO=${lib.escapeShellArg (lib.concatStringsSep "," cfg.notify.emailTo)}
            env=${lib.escapeShellArg cfg.notify.environmentFile}
            subject="''${COMIN_GIT_MSG%%$'\n'*}"
            if [ "$status" = "failed" ]; then
              neusis-notify --env-file "$env" --priority high --tags warning \
                --title "auto-update failed on $host" \
                "$host failed to deploy $short ($subject): ''${COMIN_ERROR_MSG:-no error message}" \
                || echo "neusis-auto-update-hook: notification failed" >&2
            ${lib.optionalString cfg.notify.onSuccess ''
              elif [ "$status" = "done" ]; then
                neusis-notify --env-file "$env" --priority min --tags white_check_mark --no-email \
                  --title "$host deployed $short" "$subject" \
                  || echo "neusis-auto-update-hook: notification failed" >&2
            ''}
            fi
          ''}
        '';
      };
    in
    {
      options.neusis.services.auto-update = {
        enable = lib.mkEnableOption "pull-based auto-updates from a git branch (comin)";

        url = lib.mkOption {
          type = lib.types.str;
          example = "https://github.com/leoank/neusis.git";
          description = "Git remote holding the flake with this host's configuration.";
        };

        branch = lib.mkOption {
          type = lib.types.str;
          example = "deploy/canary";
          description = "Branch comin follows; its head is deployed with `switch`.";
        };

        pollPeriod = lib.mkOption {
          type = lib.types.ints.positive;
          default = 60;
          description = "Seconds between polls of `branch`.";
        };

        signers = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                principal = lib.mkOption { type = lib.types.str; };
                key = lib.mkOption { type = lib.types.str; };
              };
            }
          );
          default = [ ];
          description = ''
            Trusted commit signers (`registry.signers.<lab>` entries). A
            head not signed by one of them is not deployed. Empty
            disables the check, which warns.
          '';
        };

        logFile = lib.mkOption {
          type = lib.types.str;
          default = "/var/log/neusis/auto-update.jsonl";
          description = "One JSON line per deployment is appended here.";
        };

        notify = {
          environmentFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "/run/agenix/autoUpdateNotify";
            description = ''
              Dotenv file with the neusis-notify credentials
              (`NTFY_TOPIC`, optional `NTFY_TOKEN`, `POSTMARK_API_KEY`),
              typically an agenix secret. `null` disables notifications;
              the deploy log is still written.
            '';
          };
          ntfyUrl = lib.mkOption {
            type = lib.types.str;
            default = "https://ntfy.sh";
            description = "ntfy server.";
          };
          emailFrom = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Sender address (a confirmed Postmark sender signature or domain). `null` sends no email.";
          };
          emailTo = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Recipients of failure emails.";
          };
          onSuccess = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Also announce successful deployments (ntfy only, minimum priority).";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        warnings = lib.optional (cfg.signers == [ ]) ''
          neusis.services.auto-update: no signers, so comin deploys any
          commit on ${cfg.branch}. Set `signers` to require signed heads.
        '';

        services.comin = {
          enable = true;
          # comin's own module prefers `pkgs.comin` (mkDefault); pin the
          # binary to the flake the module comes from so the two agree on
          # the config schema even once nixpkgs carries an older comin.
          package = inputs.comin.packages.${system}.comin;
          remotes = [
            {
              name = "origin";
              inherit (cfg) url;
              branches.main.name = cfg.branch;
              poller.period = cfg.pollPeriod;
            }
          ];
          sshAllowedSignersPath = lib.mkIf (cfg.signers != [ ]) "${allowedSignersFile}";
          postDeploymentCommand = lib.getExe hook;
        };
      };
    };
}
