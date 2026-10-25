# Tests for flake.homeModules.rc2s2-node: the node daemon as a launchd
# agent on Darwin and a systemd user service on Linux.
{ self, ... }:
{
  perSystem =
    {
      lib,
      testPkgs,
      ...
    }:
    let
      t = self.neusis.lib.tests;
      fakePkg = testPkgs.writeShellScriptBin "rc2s2" "exit 0";
      rc2s2 = lib.getExe fakePkg;
      node =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.rc2s2-node
            {
              neusis.services.rc2s2-node = {
                enable = true;
                package = fakePkg;
                hub = "http://ghost001:7700";
                tokenFile = "/run/agenix/rc2s2NodeToken";
              }
              // extra;
            }
          ];
        };
      home = node { };
      isDarwin = testPkgs.stdenv.isDarwin;
      # The expected daemon command line (hook-addr defaults to 127.0.0.1:7777).
      cmd = "${rc2s2} node serve --hub http://ghost001:7700 --token-file /run/agenix/rc2s2NodeToken --hook-addr 127.0.0.1:7777";
    in
    {
      tests.hm-rc2s2-node = {
        test-runs-the-daemon-per-platform = {
          expr =
            if isDarwin then
              let
                a = home.launchd.agents.rc2s2-node.config;
              in
              {
                on = home.launchd.agents.rc2s2-node.enable;
                cmd = lib.last a.ProgramArguments == cmd;
                keepAlive = a.KeepAlive;
                runAtLoad = a.RunAtLoad;
                failed = t.failedAssertions home;
              }
            else
              let
                s = home.systemd.user.services.rc2s2-node;
                execStart = lib.concatStringsSep " " (lib.toList s.Service.ExecStart);
              in
              {
                on = s.Service.Restart == "on-failure";
                cmd = lib.hasSuffix (lib.escapeShellArg cmd) execStart;
                wantedBy = s.Install.WantedBy;
                failed = t.failedAssertions home;
              };
          expected =
            if isDarwin then
              {
                on = true;
                cmd = true;
                keepAlive = true;
                runAtLoad = true;
                failed = [ ];
              }
            else
              {
                on = true;
                cmd = true;
                wantedBy = [ "default.target" ];
                failed = [ ];
              };
        };

        test-name-and-extra-args = {
          expr =
            let
              h = node {
                name = "rogue";
                ignoreCwd = [ "*/target/live-work-*" ];
                extraArgs = [
                  "--hold-secs"
                  "60"
                ];
              };
              line =
                if isDarwin then
                  lib.last h.launchd.agents.rc2s2-node.config.ProgramArguments
                else
                  lib.concatStringsSep " " (lib.toList h.systemd.user.services.rc2s2-node.Service.ExecStart);
            in
            {
              hasName = lib.hasInfix "--name rogue" line;
              hasIgnore = lib.hasInfix "--ignore-cwd '*/target/live-work-*'" line;
              hasExtra = lib.hasInfix "--hold-secs 60" line;
            };
          expected = {
            hasName = true;
            hasIgnore = true;
            hasExtra = true;
          };
        };
      };
    };
}
