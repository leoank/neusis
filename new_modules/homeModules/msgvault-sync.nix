# Neusis msgvault-sync home-manager module.
# Opt-in scheduled job that runs `msgvault sync` periodically.
# Cross-platform: launchd agent on Darwin, systemd user service +
# timer on Linux. Configure via `neusis.services.msgvault-sync.*`.
{ ... }:
{
  flake-file.inputs = {
    msgvault = {
      url = "github:wesm/msgvault";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  flake.homeModules.msgvault-sync =
    {
      config,
      pkgs,
      inputs,
      lib,
      ...
    }:
    let
      cfg = config.neusis.services.msgvault-sync;
    in
    {
      options.neusis.services.msgvault-sync = {
        enable = lib.mkEnableOption "scheduled msgvault sync job";

        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.msgvault.packages.${pkgs.stdenv.hostPlatform.system}.default;
          defaultText = lib.literalExpression "inputs.msgvault.packages.\${system}.default";
          description = "The msgvault package to invoke.";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "sync" ];
          example = [
            "sync"
            "--verbose"
          ];
          description = ''
            Arguments passed to the msgvault binary. Defaults to a
            single `sync` arg; override to add flags or run a
            different subcommand.
          '';
        };

        launchdSchedule = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [
            { Minute = 0; }
            { Minute = 15; }
            { Minute = 30; }
            { Minute = 45; }
          ];
          example = [ { Hour = 9; } ];
          description = ''
            Value for launchd's `StartCalendarInterval` (Darwin only).
            Each entry is an attrset of `{ Minute?; Hour?; Day?;
            Month?; Weekday?; }` — kanata-style cron. Defaults to
            every quarter-hour.
          '';
        };

        systemdOnCalendar = lib.mkOption {
          type = lib.types.str;
          default = "*:0/15";
          example = "hourly";
          description = ''
            Value for systemd's `OnCalendar=` (Linux only). Defaults
            to every quarter-hour. See `man systemd.time` for syntax.
          '';
        };

        logDir = lib.mkOption {
          type = lib.types.str;
          default = "/tmp";
          example = "/var/log/msgvault";
          description = ''
            Directory for stdout/stderr log files on Darwin (launchd
            writes `<logDir>/msgvault-sync.{out,err}.log`). Linux
            output goes to the user journal regardless — query with
            `journalctl --user -u msgvault-sync`.
          '';
        };
      };

      config = lib.mkIf cfg.enable (lib.mkMerge [
        # Darwin: user launchd agent.
        (lib.mkIf pkgs.stdenv.isDarwin {
          launchd.agents.msgvault-sync = {
            enable = true;
            config = {
              ProgramArguments = [ (lib.getExe cfg.package) ] ++ cfg.extraArgs;
              StartCalendarInterval = cfg.launchdSchedule;
              StandardErrorPath = "${cfg.logDir}/msgvault-sync.err.log";
              StandardOutPath = "${cfg.logDir}/msgvault-sync.out.log";
            };
          };
        })

        # Linux: systemd user service + timer.
        (lib.mkIf pkgs.stdenv.isLinux {
          systemd.user.services.msgvault-sync = {
            Unit.Description = "Incremental Gmail sync via msgvault";
            Service = {
              Type = "oneshot";
              ExecStart = lib.escapeShellArgs ([ (lib.getExe cfg.package) ] ++ cfg.extraArgs);
            };
          };
          systemd.user.timers.msgvault-sync = {
            Unit.Description = "Run msgvault-sync on a schedule";
            Timer = {
              OnCalendar = cfg.systemdOnCalendar;
              # Run missed invocations on wake/boot — robustness over
              # strict launchd-style "skip if asleep".
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        })
      ]);
    };
}
