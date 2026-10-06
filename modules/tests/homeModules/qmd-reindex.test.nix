# Tests for flake.homeModules.qmd-reindex: a scheduled `qmd update && qmd
# embed` job — launchd agent on Darwin, systemd user timer on Linux.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      job =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.qmd-reindex
            { neusis.services.qmd-reindex = { enable = true; } // extra; }
          ];
        };
      home = job { };
      isDarwin = testPkgs.stdenv.isDarwin;
      qmd = lib.getExe home.neusis.services.qmd-reindex.package;
      chain = "${qmd} update && ${qmd} embed";
    in
    {
      tests.hm-qmd-reindex = {
        test-schedules-the-chained-command-per-platform = {
          expr =
            if isDarwin then
              let
                a = home.launchd.agents.qmd-reindex.config;
              in
              {
                on = home.launchd.agents.qmd-reindex.enable;
                cmd = lib.last a.ProgramArguments == chain;
                schedule = map (i: i.Minute) a.StartCalendarInterval;
                err = a.StandardErrorPath;
                failed = t.failedAssertions home;
              }
            else
              let
                s = home.systemd.user.services.qmd-reindex;
                tm = home.systemd.user.timers.qmd-reindex;
                # home-manager normalises unit values to lists
                execStart = lib.concatStringsSep " " (lib.toList s.Service.ExecStart);
              in
              {
                on = s.Service.Type == "oneshot";
                cmd = lib.hasSuffix (lib.escapeShellArg chain) execStart;
                schedule = [ tm.Timer.OnCalendar ];
                err = if tm.Timer.Persistent then "/tmp/qmd-reindex.err.log" else "not persistent";
                failed = t.failedAssertions home;
              };
          expected = {
            on = true;
            cmd = true;
            schedule = if isDarwin then [ 20 ] else [ "*:20" ];
            err = "/tmp/qmd-reindex.err.log";
            failed = [ ];
          };
        };

        test-subcommands-and-schedule-are-configurable = {
          expr =
            let
              cfg = job {
                subcommands = [ "vacuum" ];
                launchdSchedule = [ { Hour = 3; } ];
                systemdOnCalendar = "daily";
                logDir = "/var/log/qmd";
              };
              q = lib.getExe cfg.neusis.services.qmd-reindex.package;
            in
            if isDarwin then
              {
                cmd = lib.last cfg.launchd.agents.qmd-reindex.config.ProgramArguments;
                schedule = toString (lib.head cfg.launchd.agents.qmd-reindex.config.StartCalendarInterval).Hour;
                out = cfg.launchd.agents.qmd-reindex.config.StandardOutPath;
              }
            else
              {
                cmd = lib.removeSuffix "'" (
                  lib.last (
                    lib.splitString "-c '" (
                      lib.concatStringsSep " " (lib.toList cfg.systemd.user.services.qmd-reindex.Service.ExecStart)
                    )
                  )
                );
                schedule = cfg.systemd.user.timers.qmd-reindex.Timer.OnCalendar;
                out = "/var/log/qmd/qmd-reindex.out.log";
              };
          expected = {
            cmd = "${lib.getExe home.neusis.services.qmd-reindex.package} vacuum";
            schedule = if isDarwin then "3" else "daily";
            out = "/var/log/qmd/qmd-reindex.out.log";
          };
        };

        test-disabled-schedules-nothing = {
          expr =
            let
              cfg = t.evalHm {
                pkgs = testPkgs;
                modules = [ self.homeModules.qmd-reindex ];
              };
            in
            {
              launchd = cfg.launchd.agents ? qmd-reindex;
              systemd = cfg.systemd.user.services ? qmd-reindex;
            };
          expected = {
            launchd = false;
            systemd = false;
          };
        };
      };
    };
}
