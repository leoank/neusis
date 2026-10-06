# Tests for flake.homeModules.supercharged-git-multi-account
# (neusis.supercharged-git.tools.multi-account), through the umbrella.
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
            { neusis.supercharged-git.tools.multi-account = { enable = true; } // extra; }
          ];
        };

      home = withTool { inherit accounts; };
      off = t.evalHm {
        pkgs = testPkgs;
        modules = [
          self.homeModules.supercharged-git
          f.gitIdentity
        ];
      };

      # `home` above is built with these accounts.
      accounts = {
        work = {
          userName = "Alice Work";
          userEmail = "alice@work.example";
          sshKey = "~/.ssh/id_ed25519_work";
          signingKey = "~/.ssh/id_ed25519_work.pub";
          directories = [ "~/code/work" ];
          orgs = [ "acme" ];
        };
        personal = {
          userName = "Alice Fixture";
          userEmail = "alice@example.com";
          sshKey = "~/.ssh/id_ed25519";
          sshAlias = "gh-personal";
        };
      };
    in
    {
      tests.hm-supercharged-git-multi-account = {
        test-accounts-produce-ssh-aliases-includes-and-url-rewrites = {
          expr =
            let
              # settings is a DAG: each entry is { after; before; data; }
              work = home.programs.ssh.settings."github.com-work".data;
            in
            {
              aliases = lib.sort lib.lessThan (
                lib.filter (n: n != "*") (builtins.attrNames home.programs.ssh.settings)
              );
              work = {
                inherit (work)
                  HostName
                  User
                  IdentityFile
                  IdentitiesOnly
                  ;
              };
              legacyDefaults = home.programs.ssh.enableDefaultConfig;
              noLegacyBlocks = home.programs.ssh.matchBlocks;
              includes = map (i: {
                inherit (i) condition;
                user = i.contents.user;
              }) home.programs.git.includes;
              urls = lib.mapAttrs (_: u: u.insteadOf) home.programs.git.settings.url;
              failed = t.failedAssertions home;
            };
          expected = {
            aliases = [
              "gh-personal"
              "github.com-work"
            ];
            work = {
              HostName = "github.com";
              User = "git";
              IdentityFile = "~/.ssh/id_ed25519_work";
              IdentitiesOnly = true;
            };
            legacyDefaults = false;
            noLegacyBlocks = { };
            includes = [
              {
                condition = "gitdir:~/code/work/";
                user = {
                  name = "Alice Work";
                  email = "alice@work.example";
                  signingkey = "~/.ssh/id_ed25519_work.pub";
                };
              }
            ];
            # personal has no orgs, so no rewrite entry for it
            urls."git@github.com-work:" = [ "git@github.com:acme/" ];
            failed = [ ];
          };
        };

        test-disabled-adds-no-ssh-config = {
          expr = {
            ssh = off.programs.ssh.enable;
            includes = off.programs.git.includes;
          };
          expected = {
            ssh = false;
            includes = [ ];
          };
        };
      };
    };
}
