# Neusis supercharged-git home-manager module.
# Umbrella module: opinionated git defaults (SSH-signed commits, LFS,
# allowed_signers) plus an opt-in toolkit of related CLIs/TUIs.
#
# Importing this module brings in *all* the tool sub-modules so their
# `neusis.supercharged-git.tools.<name>.enable` options are declared.
# Each tool defaults to disabled — enable them piecemeal.
#
# Configure via `neusis.supercharged-git.*`. At minimum `userName`
# and `userEmail` need to be set.
{ self, ... }:
{
  flake.homeModules.supercharged-git =
    {
      config,
      lib,
      pkgs,
      outputs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git;
    in
    {
      # Pull in every tool sub-module so the user can flip
      # `neusis.supercharged-git.tools.<name>.enable` without
      # individual imports.
      imports = [
        self.homeModules.supercharged-git-gh
        self.homeModules.supercharged-git-lazygit
        self.homeModules.supercharged-git-delta
        self.homeModules.supercharged-git-pre-commit
        self.homeModules.supercharged-git-commitizen
        self.homeModules.supercharged-git-gh-dash
        self.homeModules.supercharged-git-jujutsu
        self.homeModules.supercharged-git-act
        self.homeModules.supercharged-git-mergiraf
        self.homeModules.supercharged-git-gitleaks
        self.homeModules.supercharged-git-graphite
        self.homeModules.supercharged-git-multi-account
        self.homeModules.supercharged-git-bootstrap-repos
      ];

      options.neusis.supercharged-git = {
        enable = lib.mkEnableOption "neusis-managed git setup (SSH-signed commits, LFS)";

        userName = lib.mkOption {
          type = lib.types.str;
          example = "Ankur Kumar";
          description = "Git author/committer name.";
        };

        userEmail = lib.mkOption {
          type = lib.types.str;
          example = "ank@example.com";
          description = "Git author/committer email.";
        };

        signCommits = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Sign every commit (`commit.gpgsign = true`) using the SSH
            signing key. Set `false` to skip signing entirely.
          '';
        };

        signingKey = lib.mkOption {
          type = lib.types.str;
          default = "~/.ssh/id_ed25519.pub";
          example = "~/.ssh/id_ed25519_yubi.pub";
          description = ''
            Path to the SSH public key used to sign commits. Passed
            verbatim to git's `user.signingkey`.
          '';
        };

        allowedSignersPubkey = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI…";
          description = ''
            Public key content (raw, single line) for the SSH
            `allowed_signers` file used by `git verify-commit`. When
            non-null, `~/.ssh/allowed_signers` is materialised as
            `* <pubkey>` and git's `gpg.ssh.allowedSignersFile` is
            pointed at it.
          '';
        };

        lfs.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable git-lfs.";
        };
      };

      config = lib.mkIf cfg.enable (lib.mkMerge [
        {
          # Ship `gclb` (git-clone-bare-with-worktree) on every user
          # whose home-manager bundle imports this umbrella. The
          # package itself is defined as a flake-parts perSystem
          # output under `new_modules/packages/gclb/`.
          home.packages = [ outputs.packages.${pkgs.stdenv.hostPlatform.system}.gclb ];

          programs.git = {
            enable = true;
            lfs.enable = cfg.lfs.enable;
            settings = {
              user = {
                name = cfg.userName;
                email = cfg.userEmail;
              };
            }
            // lib.optionalAttrs cfg.signCommits {
              user.signingkey = cfg.signingKey;
              commit.gpgsign = true;
              gpg.format = "ssh";
            };
          };
        }

        # Stage the allowed_signers file + point git at it. Independent
        # of `signCommits` so you can verify signatures even if you
        # don't sign your own commits.
        (lib.mkIf (cfg.allowedSignersPubkey != null) {
          home.file.".ssh/allowed_signers".text = "* ${cfg.allowedSignersPubkey}";
          programs.git.settings.gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        })
      ]);
    };
}
