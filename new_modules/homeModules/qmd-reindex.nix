# Neusis qmd-reindex home-manager module.
# Registers a user-level scheduled job that runs `qmd update && qmd
# embed` every hour at HH:20. Picks the qmd package matching the
# host's system from the `llm-agents` flake input.
#
# Cross-platform: launchd agent on Darwin, systemd user service +
# timer on Linux. Chaining of the two `qmd` invocations goes through
# `bash -c "… && …"` on both platforms — neither launchd's
# `ProgramArguments` nor systemd's `ExecStart` runs a shell on its
# own, so the shell is explicit.
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
      pkgs,
      inputs,
      lib,
      ...
    }:
    let
      qmd = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd;
      # The chained command, identical on both platforms.
      chainedCmd = "${qmd}/bin/qmd update && ${qmd}/bin/qmd embed";
    in
    {
      config = lib.mkMerge [
        # Darwin: user launchd agent. Logs go to /tmp/.
        (lib.mkIf pkgs.stdenv.isDarwin {
          launchd.agents.qmd-reindex = {
            enable = true;
            config = {
              ProgramArguments = [
                "${pkgs.bash}/bin/bash"
                "-c"
                chainedCmd
              ];
              StartCalendarInterval = [
                { Minute = 20; }
              ];
              StandardErrorPath = "/tmp/qmd-reindex.err.log";
              StandardOutPath = "/tmp/qmd-reindex.out.log";
            };
          };
        })

        # Linux: systemd user service + timer. Output goes to the
        # user journal (`journalctl --user -u qmd-reindex`).
        (lib.mkIf pkgs.stdenv.isLinux {
          systemd.user.services.qmd-reindex = {
            Unit.Description = "qmd reindex + embed";
            Service = {
              Type = "oneshot";
              ExecStart = "${pkgs.bash}/bin/bash -c '${chainedCmd}'";
            };
          };
          systemd.user.timers.qmd-reindex = {
            Unit.Description = "Run qmd-reindex hourly at HH:20";
            Timer = {
              OnCalendar = "*:20";
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        })
      ];
    };
}
