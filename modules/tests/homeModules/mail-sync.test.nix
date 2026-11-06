# Tests for flake.homeModules.mail-sync: a scheduled `mbsync -a; notmuch
# new` job — launchd agent on Darwin, systemd user timer on Linux.
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
            self.homeModules.mail-sync
            {
              programs.mbsync.enable = true;
              neusis.services.mail-sync.enable = true;
            }
            extra
          ];
        };
      # notmuch refuses to configure without a primary notmuch account.
      withNotmuch = {
        programs.notmuch.enable = true;
        accounts.email.accounts.t = {
          primary = true;
          address = "t@example.org";
          realName = "T";
          notmuch.enable = true;
        };
      };
      isDarwin = testPkgs.stdenv.isDarwin;
      # The command the job runs, from launchd's or systemd's unit.
      commandOf =
        home:
        if isDarwin then
          lib.last home.launchd.agents.mail-sync.config.ProgramArguments
        else
          lib.removeSuffix "'" (
            lib.last (
              lib.splitString "-c '" (
                lib.concatStringsSep " " (lib.toList home.systemd.user.services.mail-sync.Service.ExecStart)
              )
            )
          );
      intervalOf =
        home:
        if isDarwin then
          home.launchd.agents.mail-sync.config.StartInterval
        else
          home.systemd.user.timers.mail-sync.Timer.OnUnitActiveSec;
    in
    {
      tests.hm-mail-sync = {
        # notmuch indexes after every sync, even when one account failed
        # (`;`, not `&&`).
        test-syncs-then-indexes-every-five-minutes = {
          expr =
            let
              home = job withNotmuch;
            in
            {
              cmd = commandOf home;
              interval = intervalOf home;
              failed = t.failedAssertions home;
            };
          expected =
            let
              home = job withNotmuch;
            in
            {
              cmd = "${home.programs.mbsync.package}/bin/mbsync -a; ${home.programs.notmuch.package}/bin/notmuch new";
              interval = if isDarwin then 300 else "300s";
              failed = [ ];
            };
        };

        test-without-notmuch-only-syncs = {
          expr =
            let
              home = job { neusis.services.mail-sync.interval = 900; };
            in
            {
              cmd = commandOf home;
              interval = intervalOf home;
            };
          expected = {
            cmd = "${(job { }).programs.mbsync.package}/bin/mbsync -a";
            interval = if isDarwin then 900 else "900s";
          };
        };

        test-needs-mbsync = {
          expr = commandOf (
            t.evalHm {
              pkgs = testPkgs;
              modules = [
                self.homeModules.mail-sync
                { neusis.services.mail-sync.enable = true; }
              ];
            }
          );
          expectedError = {
            type = "ThrownError";
            msg = "neusis.services.mail-sync needs programs.mbsync.enable";
          };
        };

        test-disabled-schedules-nothing = {
          expr =
            let
              cfg = t.evalHm {
                pkgs = testPkgs;
                modules = [ self.homeModules.mail-sync ];
              };
            in
            {
              launchd = cfg.launchd.agents ? mail-sync;
              systemd = cfg.systemd.user.services ? mail-sync;
            };
          expected = {
            launchd = false;
            systemd = false;
          };
        };
      };
    };
}
