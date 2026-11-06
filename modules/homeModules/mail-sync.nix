# Neusis mail-sync home-manager module.
# Opt-in scheduled job that pulls mail with `mbsync -a` and then indexes it
# with `notmuch new` (when programs.notmuch is on). Home Manager's own
# services.mbsync is Linux-only; this one is a launchd agent on Darwin and
# a systemd user service + timer on Linux, like qmd-reindex. The index
# runs even when one account fails to sync, so a server that is down does
# not hold back the others' mail.
#
# Configure via `neusis.services.mail-sync.*`; the accounts themselves are
# `accounts.email.accounts.<name>` with `mbsync.enable = true`.
{ ... }:
{
  flake.homeModules.mail-sync =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.neusis.services.mail-sync;
      command = lib.concatStringsSep "; " (
        [ "${config.programs.mbsync.package}/bin/mbsync -a" ]
        ++ lib.optional config.programs.notmuch.enable "${config.programs.notmuch.package}/bin/notmuch new"
      );
    in
    {
      options.neusis.services.mail-sync = {
        enable = lib.mkEnableOption "scheduled mbsync + notmuch mail sync";

        interval = lib.mkOption {
          type = lib.types.ints.positive;
          default = 300;
          example = 900;
          description = ''
            Seconds between syncs: launchd's `StartInterval` on Darwin,
            systemd's `OnUnitActiveSec=` on Linux. A run still in progress
            is never started twice.
          '';
        };

        logDir = lib.mkOption {
          type = lib.types.str;
          default = "/tmp";
          example = "/var/log/mail";
          description = ''
            Directory for stdout/stderr log files on Darwin (launchd writes
            `<logDir>/mail-sync.{out,err}.log`). Linux output goes to the
            user journal: `journalctl --user -u mail-sync`.
          '';
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            assertions = [
              {
                assertion = config.programs.mbsync.enable;
                message = "neusis.services.mail-sync needs programs.mbsync.enable";
              }
            ];
          }

          (lib.mkIf pkgs.stdenv.isDarwin {
            launchd.agents.mail-sync = {
              enable = true;
              config = {
                ProgramArguments = [
                  "${pkgs.bash}/bin/bash"
                  "-c"
                  command
                ];
                StartInterval = cfg.interval;
                RunAtLoad = true;
                StandardErrorPath = "${cfg.logDir}/mail-sync.err.log";
                StandardOutPath = "${cfg.logDir}/mail-sync.out.log";
              };
            };
          })

          (lib.mkIf pkgs.stdenv.isLinux {
            systemd.user.services.mail-sync = {
              Unit.Description = "mbsync + notmuch mail sync";
              Service = {
                Type = "oneshot";
                ExecStart = "${pkgs.bash}/bin/bash -c ${lib.escapeShellArg command}";
              };
            };
            systemd.user.timers.mail-sync = {
              Unit.Description = "Run mail-sync on a schedule";
              Timer = {
                OnBootSec = "2m";
                OnUnitActiveSec = "${toString cfg.interval}s";
              };
              Install.WantedBy = [ "timers.target" ];
            };
          })
        ]
      );
    };
}
