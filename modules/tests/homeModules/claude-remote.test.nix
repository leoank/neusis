# Tests for flake.homeModules.claude-remote: a Darwin launchd agent that
# keeps a `claude --remote-control` tmux session alive. No-op on Linux.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      remote =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.claude-remote
            { neusis.claude-remote = { enable = true; } // extra; }
          ];
        };
      home = remote { };
      isDarwin = testPkgs.stdenv.isDarwin;
      agent = cfg: name: cfg.launchd.agents.${name}.config;
    in
    {
      tests.hm-claude-remote = {
        test-darwin-agent-keeps-remote-control-session = {
          expr =
            if isDarwin then
              let
                a = agent home "claude-rc-admin";
                cmd = lib.last a.ProgramArguments;
              in
              {
                on = home.launchd.agents.claude-rc-admin.enable;
                session = lib.hasInfix "new-session -d -s admin-rc" cmd;
                remoteControl = lib.hasInfix "--remote-control admin" cmd;
                projectDir = lib.hasInfix "-c ${home.home.homeDirectory}/Documents/Claude/Projects/admin" cmd;
                runAtLoad = a.RunAtLoad;
                keepAlive = a.KeepAlive;
                err = a.StandardErrorPath;
                failed = t.failedAssertions home;
              }
            else
              {
                on = !(home.launchd.agents ? claude-rc-admin);
                session = true;
                remoteControl = true;
                projectDir = true;
                runAtLoad = true;
                keepAlive = false;
                err = "/tmp/claude-rc-admin.err.log";
                failed = [ ];
              };
          expected = {
            on = true;
            session = true;
            remoteControl = true;
            projectDir = true;
            runAtLoad = true;
            keepAlive = false;
            err = "/tmp/claude-rc-admin.err.log";
            failed = [ ];
          };
        };

        test-profile-derives-agent-and-session-names = {
          expr =
            let
              cfg = remote {
                profile = "work";
                claudeBin = "/opt/claude";
                logDir = "/var/log";
              };
            in
            if isDarwin then
              {
                agent = cfg.launchd.agents ? claude-rc-work;
                cmd = lib.hasInfix "-s work-rc -c" (lib.last (agent cfg "claude-rc-work").ProgramArguments);
                bin = lib.hasInfix "/opt/claude --remote-control work" (lib.last (agent cfg "claude-rc-work").ProgramArguments);
                out = (agent cfg "claude-rc-work").StandardOutPath;
              }
            else
              {
                agent = true;
                cmd = true;
                bin = true;
                out = "/var/log/claude-rc-work.out.log";
              };
          expected = {
            agent = true;
            cmd = true;
            bin = true;
            out = "/var/log/claude-rc-work.out.log";
          };
        };

        test-disabled-defines-no-agent = {
          expr =
            (t.evalHm {
              pkgs = testPkgs;
              modules = [ self.homeModules.claude-remote ];
            }).launchd.agents
            ? claude-rc-admin;
          expected = false;
        };
      };
    };
}
