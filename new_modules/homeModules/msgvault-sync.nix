# Neusis msgvault-sync home-manager module.
# Registers a user-level scheduled job that runs `msgvault sync` every
# 15 minutes. Picks the msgvault package matching the host's system
# from the `msgvault` flake input.
#
# Cross-platform: launchd agent on Darwin, systemd user service +
# timer on Linux.
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
      pkgs,
      inputs,
      lib,
      ...
    }:
    let
      msgvault = inputs.msgvault.packages.${pkgs.stdenv.hostPlatform.system}.default;
    in
    {
      config = lib.mkMerge [
        # Darwin: user launchd agent. Logs go to /tmp/.
        (lib.mkIf pkgs.stdenv.isDarwin {
          launchd.agents.msgvault-sync = {
            enable = true;
            config = {
              ProgramArguments = [
                "${msgvault}/bin/msgvault"
                "sync"
              ];
              StartCalendarInterval = [
                { Minute = 0; }
                { Minute = 15; }
                { Minute = 30; }
                { Minute = 45; }
              ];
              StandardErrorPath = "/tmp/msgvault-sync.err.log";
              StandardOutPath = "/tmp/msgvault-sync.out.log";
            };
          };
        })

        # Linux: systemd user service + timer. Output goes to the
        # user journal (`journalctl --user -u msgvault-sync`).
        (lib.mkIf pkgs.stdenv.isLinux {
          systemd.user.services.msgvault-sync = {
            Unit.Description = "Incremental Gmail sync via msgvault";
            Service = {
              Type = "oneshot";
              ExecStart = "${msgvault}/bin/msgvault sync";
            };
          };
          systemd.user.timers.msgvault-sync = {
            Unit.Description = "Run msgvault-sync every 15 minutes";
            Timer = {
              OnCalendar = "*:0/15";
              # Run missed invocations on wake/boot. Departs slightly
              # from launchd's "skip if asleep" semantics in favour of
              # a more robust sync schedule.
              Persistent = true;
            };
            Install.WantedBy = [ "timers.target" ];
          };
        })
      ];
    };
}
