# Tests for flake.homeModules.supercharged-git-mergiraf
# (neusis.supercharged-git.tools.mergiraf), through the umbrella.
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
            { neusis.supercharged-git.tools.mergiraf = { enable = true; } // extra; }
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
      tests.hm-supercharged-git-mergiraf = {
        test-installs-mergiraf-as-git-merge-driver = {
          expr =
            let
              m = home.programs.git.settings.merge.mergiraf;
            in
            {
              pkg = t.hasPkg "mergiraf" home.home.packages;
              name = m.name;
              driverFlags = lib.hasSuffix "/bin/mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P" m.driver;
              recursive = m.recursive;
              off = off.programs.git.settings ? merge;
            };
          expected = {
            pkg = true;
            name = "mergiraf";
            driverFlags = true;
            recursive = "binary";
            off = false;
          };
        };
      };
    };
}
