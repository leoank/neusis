# Tests for flake.homeModules.supercharged-git (umbrella): identity,
# SSH commit signing, allowed_signers, LFS, gclb, and that every tool
# sub-module is declared but off by default.
{ self, ... }:
{
  perSystem =
    { lib, testPkgs, ... }:
    let
      t = self.neusis.lib.tests;
      f = t.fixtures;

      gitHome =
        extra:
        t.evalHm {
          pkgs = testPkgs;
          modules = [
            self.homeModules.supercharged-git
            f.gitIdentity
            extra
          ];
        };

      home = gitHome { };
    in
    {
      tests.hm-supercharged-git = {
        test-enable-sets-identity-signing-lfs-and-gclb = {
          expr = {
            git = home.programs.git.enable;
            user = home.programs.git.settings.user;
            gpgsign = home.programs.git.settings.commit.gpgsign;
            format = home.programs.git.settings.gpg.format;
            lfs = home.programs.git.lfs.enable;
            gclb = t.hasPkg "gclb" home.home.packages;
            failed = t.failedAssertions home;
          };
          expected = {
            git = true;
            user = {
              name = "Alice Fixture";
              email = "alice@example.com";
              signingkey = "~/.ssh/id_ed25519.pub";
            };
            gpgsign = true;
            format = "ssh";
            lfs = true;
            gclb = true;
            failed = [ ];
          };
        };

        test-sign-commits-off-keeps-identity = {
          expr =
            let
              s = (gitHome { neusis.supercharged-git.signCommits = false; }).programs.git.settings;
            in
            {
              user = s.user;
              commit = s ? commit;
              gpg = s ? gpg;
            };
          expected = {
            user = {
              name = "Alice Fixture";
              email = "alice@example.com";
            };
            commit = false;
            gpg = false;
          };
        };

        test-allowed-signers-file = {
          expr =
            let
              cfg = gitHome { neusis.supercharged-git.allowedSignersPubkey = f.hostPubkey; };
            in
            {
              file = cfg.home.file.".ssh/allowed_signers".text;
              pointer = cfg.programs.git.settings.gpg.ssh.allowedSignersFile;
              absentByDefault = home.home.file ? ".ssh/allowed_signers";
            };
          expected = {
            file = "* ${f.hostPubkey}";
            pointer = "~/.ssh/allowed_signers";
            absentByDefault = false;
          };
        };

        test-custom-signing-key-and-no-lfs = {
          expr =
            let
              cfg = gitHome {
                neusis.supercharged-git.signingKey = "~/.ssh/yubi.pub";
                neusis.supercharged-git.lfs.enable = false;
              };
            in
            {
              key = cfg.programs.git.settings.user.signingkey;
              lfs = cfg.programs.git.lfs.enable;
            };
          expected = {
            key = "~/.ssh/yubi.pub";
            lfs = false;
          };
        };

        test-all-tools-declared-and-off-by-default = {
          expr = lib.mapAttrs (_: tool: tool.enable) home.neusis.supercharged-git.tools;
          expected = lib.genAttrs [
            "act"
            "bootstrap-repos"
            "commitizen"
            "delta"
            "gh"
            "gh-dash"
            "gitleaks"
            "jujutsu"
            "lazygit"
            "mergiraf"
            "multi-account"
            "pre-commit"
          ] (_: false);
        };

        test-disabled-configures-nothing = {
          expr =
            let
              cfg = t.evalHm {
                pkgs = testPkgs;
                modules = [ self.homeModules.supercharged-git ];
              };
            in
            {
              git = cfg.programs.git.enable;
              gclb = t.hasPkg "gclb" cfg.home.packages;
            };
          expected = {
            git = false;
            gclb = false;
          };
        };
      };
    };
}
