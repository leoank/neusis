# Tests for flake.homeModules.supercharged-git-bootstrap-repos
# (neusis.supercharged-git.tools.bootstrap-repos), through the umbrella.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;

      withTool =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.supercharged-git
            f.gitIdentity
            { neusis.supercharged-git.tools.bootstrap-repos = { enable = true; } // extra; }
          ];
        };

      home = withTool { };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [
          self.homeModules.supercharged-git
          f.gitIdentity
        ];
      };
    in
    {
      tests.hm-supercharged-git-bootstrap-repos = {
        test-installs-gclb-sync-with-default-location = {
          expr = {
            script = t.hasPkg "gclb-sync" home.home.packages;
            location = home.neusis.supercharged-git.tools.bootstrap-repos.location;
            autoRun = home.home.activation ? bootstrapRepos;
            off = t.hasPkg "gclb-sync" off.home.packages;
            failed = t.failedAssertions home;
          };
          expected = {
            script = true;
            location = "${home.home.homeDirectory}/code";
            autoRun = false;
            off = false;
            failed = [ ];
          };
        };

        test-auto-run-adds-activation-step = {
          expr =
            let
              cfg = withTool {
                autoRun = true;
                location = "/srv/code";
                repos = [
                  "git@github.com:org/dotfiles.git"
                  {
                    url = "https://github.com/upstream/samples.git";
                    dest = "external/samples";
                    extraGitArgs = [ "--depth" "1" ];
                  }
                ];
              };
            in
            {
              activation = cfg.home.activation ? bootstrapRepos;
              afterWriteBoundary = builtins.elem "writeBoundary" cfg.home.activation.bootstrapRepos.after;
              location = cfg.neusis.supercharged-git.tools.bootstrap-repos.location;
              repos = builtins.length cfg.neusis.supercharged-git.tools.bootstrap-repos.repos;
            };
          expected = {
            activation = true;
            afterWriteBoundary = true;
            location = "/srv/code";
            repos = 2;
          };
        };
      };
    };
}
