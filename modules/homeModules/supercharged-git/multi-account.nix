# supercharged-git: multi-account GitHub module.
# Wires up per-account SSH host aliases, per-directory git identity
# overrides (via `[includeIf "gitdir:…"]`), and URL rewriting so that
# `git clone git@github.com:<work-org>/x` automatically routes through
# the work SSH key without you having to type the alias.
#
# The umbrella's `userName`/`userEmail`/`signingKey` act as the
# *default* identity. Each account in `accounts` overrides those
# inside its `directories` glob.
{ ... }:
{
  flake.homeModules.supercharged-git-multi-account =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.neusis.supercharged-git.tools.multi-account;

      aliasFor =
        name: account: if account.sshAlias != null then account.sshAlias else "github.com-${name}";

      # The `contents` blob for one account's `[includeIf]` entry.
      includeContents = account: {
        user = {
          name = account.userName;
          email = account.userEmail;
        }
        // lib.optionalAttrs (account.signingKey != null) {
          signingkey = account.signingKey;
        };
      };
    in
    {
      options.neusis.supercharged-git.tools.multi-account = {
        enable =
          lib.mkEnableOption "multi-account GitHub setup (SSH aliases + per-directory git identity)";

        accounts = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                userName = lib.mkOption {
                  type = lib.types.str;
                  description = "Git author/committer name for this account.";
                };

                userEmail = lib.mkOption {
                  type = lib.types.str;
                  description = "Git author/committer email for this account.";
                };

                sshKey = lib.mkOption {
                  type = lib.types.str;
                  example = "~/.ssh/id_ed25519_work";
                  description = ''
                    Path to the SSH *private* key for this account.
                    Used as the `IdentityFile` of the generated SSH
                    host alias.
                  '';
                };

                signingKey = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "~/.ssh/id_ed25519_work.pub";
                  description = ''
                    SSH *public* key path used for commit signing on
                    this account. Leave `null` to fall back to the
                    umbrella's `signingKey`.
                  '';
                };

                directories = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  example = [ "~/code/work" ];
                  description = ''
                    Directories where this account's identity should
                    apply. Each becomes an
                    `[includeIf "gitdir:<dir>/"]` block in
                    `~/.config/git/config`. Use absolute paths or
                    `~/…`; `gitdir` matches by prefix.
                  '';
                };

                orgs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  example = [
                    "my-employer"
                    "another-work-org"
                  ];
                  description = ''
                    GitHub orgs whose `git@github.com:<org>/…` URLs
                    get rewritten to use this account's SSH alias
                    automatically (via git's `url.<alias>.insteadOf`).
                    Means `git clone git@github.com:my-employer/x`
                    just works with the right key, no manual alias.
                  '';
                };

                sshAlias = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  example = "github-work";
                  description = ''
                    SSH host alias written to `~/.ssh/config`.
                    Defaults to `github.com-<account-name>`.
                  '';
                };
              };
            }
          );
          default = { };
          example = lib.literalExpression ''
            {
              work = {
                userName = "Ankur Kumar";
                userEmail = "ank@employer.com";
                sshKey = "~/.ssh/id_ed25519_work";
                signingKey = "~/.ssh/id_ed25519_work.pub";
                directories = [ "~/code/work" ];
                orgs = [ "my-employer" ];
              };
              personal = {
                userName = "ank";
                userEmail = "ank@example.com";
                sshKey = "~/.ssh/id_ed25519";
                directories = [ "~/code/personal" ];
              };
            }
          '';
          description = ''
            Map of account name → settings. The account name is used
            in the default SSH alias (`github.com-<name>`).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        # One SSH host alias per account.
        programs.ssh = {
          enable = true;
          matchBlocks = lib.mapAttrs' (
            name: account:
            lib.nameValuePair (aliasFor name account) {
              hostname = "github.com";
              user = "git";
              identityFile = account.sshKey;
              identitiesOnly = true;
            }
          ) cfg.accounts;
        };

        # Per-directory git identity overrides via `[includeIf]`.
        programs.git.includes = lib.concatLists (
          lib.mapAttrsToList (
            _: account:
            map (dir: {
              condition = "gitdir:${dir}/";
              contents = includeContents account;
            }) account.directories
          ) cfg.accounts
        );

        # URL rewriting per account: one `url.<alias>:` section
        # gathering every org's `insteadOf` line.
        programs.git.settings.url = lib.filterAttrs (_: v: v.insteadOf != [ ]) (
          lib.mapAttrs' (
            name: account:
            lib.nameValuePair "git@${aliasFor name account}:" {
              insteadOf = map (org: "git@github.com:${org}/") account.orgs;
            }
          ) cfg.accounts
        );
      };
    };
}
