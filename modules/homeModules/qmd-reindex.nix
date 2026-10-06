# Neusis qmd-reindex home-manager module.
# Opt-in scheduled job that chains a list of `qmd` subcommands
# (default: `qmd update && qmd embed`). Cross-platform: launchd agent
# on Darwin, systemd user service + timer on Linux. Chaining is via
# explicit `bash -c "…"` since neither launchd's `ProgramArguments`
# nor systemd's `ExecStart` runs a shell on its own.
#
# Configure via `neusis.services.qmd-reindex.*`.
{ ... }:
{
  flake-file.inputs = {
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  flake.homeModules.qmd-reindex =
    {
      config,
      pkgs,
      inputs,
      lib,
      ...
    }:
    let
      cfg = config.neusis.services.qmd-reindex;
      # Build the `cmd1 && cmd2 && …` chain from the subcommand list.
      chainedCmd = lib.concatMapStringsSep " && " (
        sub: "${lib.getExe cfg.package} ${sub}"
      ) cfg.subcommands;
    in
    {
      options.neusis.services.qmd-reindex = {
        enable = lib.mkEnableOption "scheduled qmd reindex job";

        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd;
          defaultText = lib.literalExpression "inputs.llm-agents.packages.\${system}.qmd";
          description = "The qmd package to invoke.";
        };

        subcommands = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "update"
            "embed"
          ];
          example = [
            "update"
            "embed --model gpt-4o"
            "vacuum"
          ];
          description = ''
            Subcommands to chain. Each entry is everything after the
            `qmd` binary (space-separated). They are joined with
            `&&` so a failure short-circuits the chain.
          '';
        };

        launchdSchedule = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ { Minute = 20; } ];
          example = [ { Hour = 3; } ];
          description = ''
            Value for launchd's `StartCalendarInterval` (Darwin
            only). Defaults to hourly at HH:20.
          '';
        };

        systemdOnCalendar = lib.mkOption {
          type = lib.types.str;
          default = "*:20";
          example = "daily";
          description = ''
            Value for systemd's `OnCalendar=` (Linux only). Defaults
            to hourly at HH:20.
          '';
        };

        logDir = lib.mkOption {
          type = lib.types.str;
          default = "/tmp";
          example = "/var/log/qmd";
          description = ''
            Directory for stdout/stderr log files on Darwin (launchd
            writes `<logDir>/qmd-reindex.{out,err}.log`). Linux
            output goes to the user journal regardless — query with
            `journalctl --user -u qmd-reindex`.
          '';
        };
      };

      config = lib.mkIf cfg.enable (lib.mkMerge [
        # Darwin: user launchd agent.
        (lib.mkIf pkgs.stdenv.isDarwin {
          launchd.agents.qmd-reindex = {
            enable = true;
            config = {
              ProgramArguments = [
                "${pkgs.bash}/bin/bash"
                "-c"
                chainedCmd
              ];
              StartCalendarInterval = cfg.launchdSchedule;
              StandardErrorPath = "${cfg.logDir}/qmd-reindex.err.log";
              StandardOutPath = "${cfg.logDir}/qmd-reindex.out.log";
            };
          };
        })

        # Linux: systemd user service + timer.
        (lib.mkIf pkgs.stdenv.isLinux {
          systemd.user.services.qmd-reindex = {
            Unit.Description = "qmd reindex + embed";
            Service = {
              Type = "oneshot";
              ExecStart = "${pkgs.bash}/bin/bash -c ${lib.escapeShellArg chainedCmd}";
            };
          };
          systemd.user.timers.qmd-reindex = {
            Unit.Description = "Run qmd-reindex on a schedule";
            Timer = {
              OnCalendar = cfg.systemdOnCalendar;
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        })
      ]);
    };
}
