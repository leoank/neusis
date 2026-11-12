# Invariants of the real `rogue` host and `ank@rogue` home. These evaluate
# the live configurations and encode policy: stateVersions are never
# bumped with nixpkgs; the primary user, hostname, mesh/builders wiring.
{ self, ... }:
{
  perSystem =
    { lib, ... }:
    let
      t = self.neusis.lib.tests;
      cfg = self.darwinConfigurations.rogue.config;
      home = self.homeConfigurations."ank@rogue".config;
      m = self.neusis.machines.rogue;
    in
    {
      tests.machine-rogue = {
        test-identity = {
          expr = {
            host = cfg.networking.hostName;
            computerName = cfg.networking.computerName;
            primaryUser = cfg.system.primaryUser;
            platform = self.darwinConfigurations.rogue.pkgs.stdenv.hostPlatform.system;
            homebrewUser = cfg.nix-homebrew.user;
            hostPubkey = cfg.neusis.services.secrets.hostPubkey == m.hostPubkey;
          };
          expected = {
            host = "rogue";
            computerName = "rogue";
            primaryUser = "ank";
            platform = "aarch64-darwin";
            homebrewUser = "ank";
            hostPubkey = true;
          };
        };

        # Policy: stateVersion records the release a host/home was created
        # under and is NOT bumped with nixpkgs (AGENTS.md).
        test-state-versions-are-pinned = {
          expr = {
            system = cfg.system.stateVersion;
            homeIntegrated = cfg.home-manager.users.ank.home.stateVersion;
            homeStandalone = home.home.stateVersion;
          };
          expected = {
            system = 5;
            homeIntegrated = "25.11";
            homeStandalone = "25.11";
          };
        };

        test-users-and-homes = {
          expr = {
            hmUsers = builtins.attrNames cfg.home-manager.users;
            ankShell = lib.getName cfg.users.users.ank.shell;
            ankHome = cfg.users.users.ank.home;
            standaloneUser = home.home.username;
            standaloneHome = home.home.homeDirectory;
            # the same bundles power the integrated and standalone homes
            kalam = t.hasPkg "nixvim" home.home.packages && t.hasPkg "nixvim" cfg.home-manager.users.ank.home.packages;
            neusisCli = t.hasPkg "neusis" home.home.packages;
            yajnaConfig = home.xdg.configFile."yajna/config.toml".text;
            # yajna's zsh completion is sourced in ank's zsh
            yajnaCompletion = lib.hasInfix "yajna-zsh-completion" home.programs.zsh.initContent;
            # claude runs under `saarthi run` where the saarthi node daemon runs
            claudeUnderSaarthi = home.neusis.agent-harness.tools.claude.saarthi.enable;
          };
          expected = {
            hmUsers = [ "ank" ];
            ankShell = "zsh";
            ankHome = "/Users/ank";
            standaloneUser = "ank";
            standaloneHome = "/Users/ank";
            kalam = true;
            neusisCli = true;
            yajnaCompletion = true;
            claudeUnderSaarthi = true;
            yajnaConfig = ''
              default = "manthan"

              [repos]
              manthan = "/Users/ank/workspace/chaos/manthan/main"
              saarthi = "/Users/ank/workspace/hub/leoank/rc2s2"
              yajna = "/Users/ank/workspace/chaos/yajna/main"
            '';
          };
        };

        test-services = {
          expr = {
            linuxBuilder = cfg.nix.linux-builder.enable;
            kanata = cfg.neusis.services.kanata.enable;
            buildServer = cfg.neusis.services.build-server.enable;
            buildsOffloadTo = map (b: b.hostName) cfg.nix.buildMachines;
            # meshes are commented out on rogue: daemon present, no profiles
            tailscale = cfg.neusis.services.tailscale.enable;
            homebrew = cfg.homebrew.enable;
            ssh = cfg.services.openssh.enable;
          };
          expected = {
            linuxBuilder = false;
            kanata = true;
            buildServer = true;
            # spirit/oppy from the registry; the linux-builder VM is no
            # longer imported (memory) and darwin001 is deliberately not a
            # builder for rogue
            buildsOffloadTo = [
              "spirit"
              "oppy"
              "ghost001"
            ];
            tailscale = false;
            homebrew = true;
            ssh = true;
          };
        };

        # The saarthi node daemon is wired on rogue (launchd agent), pointed at
        # the ghost001 hub with its token from an agenix home secret, and the
        # `saarthi` binary is on PATH for the wrapper and ctl; the token
        # files live under ~/.config/saarthi.
        test-saarthi-node = {
          expr =
            let
              agent = home.launchd.agents.saarthi-node;
              line = lib.last agent.config.ProgramArguments;
            in
            {
              enabled = agent.enable;
              keepAlive = agent.config.KeepAlive;
              hub = lib.hasInfix "--hub http://ghost001:7700" line;
              name = lib.hasInfix "--name rogue" line;
              tokenFromSecret = lib.hasInfix "--token-file ${home.age.secrets.saarthiRogueNodeToken.path}" line;
              spawnRoot = lib.hasInfix "--spawn-root /Users/ank/workspace" line;
              profiles = lib.hasInfix "--profiles /nix/store/" line;
              sandbox =
                let
                  p = home.services.saarthi-node.profiles.sandbox;
                in
                {
                  inherit (p) backend;
                  tokenFromSecret = p.token_file == home.age.secrets.saarthiSandboxClaudeToken.path;
                  stateDir = p.state_dir;
                };
              onPath = t.hasPkg "saarthi" home.home.packages;
              tokenPath = home.age.secrets.saarthiRogueNodeToken.path;
              oldAgent = home.launchd.agents ? rc2s2-node;
              # `saarthi ctl` and `saarthi tui` find the hub and their own client token
              ctl = home.xdg.configFile."saarthi/ctl.toml".text;
            };
          expected = {
            enabled = true;
            keepAlive = true;
            hub = true;
            name = true;
            tokenFromSecret = true;
            spawnRoot = true;
            profiles = true;
            sandbox = {
              backend = "seatbelt";
              tokenFromSecret = true;
              stateDir = "~/.local/state/saarthi/sandbox";
            };
            onPath = true;
            tokenPath = "/Users/ank/.config/saarthi/node-token";
            oldAgent = false;
            ctl = ''
              hub = "http://ghost001:7700"
              token_file = "/Users/ank/.config/saarthi/client-token"
            '';
          };
        };

        # Mail (ADR-0019): four accounts synced by mbsync, indexed by notmuch,
        # read in aerc. Passwords come from agenix secrets at stable paths;
        # the Microsoft 365 account signs in with an oama access token.
        test-mail = {
          expr =
            let
              accounts = home.accounts.email.accounts;
              on = a: a.mbsync.enable && a.notmuch.enable && a.aerc.enable;
            in
            {
              accounts = lib.mapAttrs (_: a: {
                inherit (a) address;
                synced = on a;
              }) accounts;
              primary = lib.attrNames (lib.filterAttrs (_: a: a.primary) accounts);
              passwords = lib.mapAttrs (_: a: {
                cat = lib.hasSuffix "/bin/cat" (lib.head a.passwordCommand);
                file = lib.last a.passwordCommand;
              }) (lib.filterAttrs (n: _: n != "cam") accounts);
              camToken = lib.hasSuffix "/bin/oama access ak2396@cam.ac.uk" (
                lib.concatStringsSep " " accounts.cam.passwordCommand
              );
              camAuth = {
                mbsync = accounts.cam.mbsync.extraConfig.account.AuthMechs;
                inherit (accounts.cam.aerc) imapAuth smtpAuth;
              };
              sync = home.launchd.agents.mail-sync.enable;
              # The XOAUTH2 plugin is visible to every account; the password
              # accounts must not offer their password as a bearer token.
              authMechs = lib.mapAttrs (_: a: a.mbsync.extraConfig.account.AuthMechs or null) accounts;
              # mbsync's errors can quote the sign-in exchange: never /tmp.
              logDir = home.neusis.services.mail-sync.logDir;
              # aerc shows no body without filters (HM's aerc.conf replaces aerc's own).
              bodyFilter = home.programs.aerc.extraConfig.filters."text/plain";
              # Code attachments by file name, ahead of text/plain (first match
              # wins, keys are sorted): bat, without paging.
              codeFilter =
                let
                  f = home.programs.aerc.extraConfig.filters;
                  key = lib.findFirst (lib.hasPrefix ".filename,~") null (lib.attrNames f);
                in
                {
                  beforePlain = key != null && key < "text/plain";
                  py = key != null && builtins.match ".*[|(]py[|)].*" key != null;
                  bat = key != null && lib.hasInfix "/bin/bat -fP" f.${key};
                };
              # oama sets the keychain item's access list only on create, so a
              # token refresh doesn't ask for the keychain password.
              oamaPatched = lib.any (pa: lib.hasSuffix "oama-keychain-update.patch" (toString pa)) (
                lib.head (lib.filter (pk: (pk.pname or "") == "oama") home.home.packages)
              ).patches;
            };
          expected = {
            accounts = {
              leoank = {
                address = "ank@leoank.me";
                synced = true;
              };
              gmail = {
                address = "leoank98@gmail.com";
                synced = true;
              };
              mrclmb = {
                address = "kumar@mrclmb.ac.uk";
                synced = true;
              };
              cam = {
                address = "ak2396@cam.ac.uk";
                synced = true;
              };
            };
            primary = [ "leoank" ];
            passwords = {
              leoank = {
                cat = true;
                file = "/Users/ank/.config/mail/mailMigadu";
              };
              gmail = {
                cat = true;
                file = "/Users/ank/.config/mail/mailGmail";
              };
              mrclmb = {
                cat = true;
                file = "/Users/ank/.config/mail/mailMrclmb";
              };
            };
            camToken = true;
            camAuth = {
              mbsync = "XOAUTH2";
              imapAuth = "xoauth2";
              smtpAuth = "xoauth2";
            };
            sync = true;
            authMechs = {
              leoank = "PLAIN";
              gmail = "PLAIN";
              mrclmb = "PLAIN";
              cam = "XOAUTH2";
            };
            logDir = "/Users/ank/Library/Logs";
            bodyFilter = "colorize";
            codeFilter = {
              beforePlain = true;
              py = true;
              bat = true;
            };
            oamaPatched = true;
          };
        };

        # Enrolled in auto-updates as the canary: comin polls this repo's
        # deploy/canary every minute, trusts only the registry signers and
        # emails failures through the notify secret.
        test-auto-update = {
          expr = {
            inherit (cfg.services.comin) enable;
            remotes = map (r: {
              inherit (r) url;
              branch = r.branches.main.name;
              period = r.poller.period;
            }) cfg.services.comin.remotes;
            signers = cfg.services.comin.sshAllowedSignersPath != null;
            notify = cfg.neusis.services.auto-update.notify.environmentFile;
            emailTo = cfg.neusis.services.auto-update.notify.emailTo;
            # comin's daemon has no App Management permission (2026-11-01).
            appManagementCheck = cfg.home-manager.users.ank.targets.darwin.copyApps.enableChecks;
          };
          expected = {
            enable = true;
            remotes = [
              {
                url = "https://github.com/leoank/neusis.git";
                branch = "deploy/canary";
                period = 60;
              }
            ];
            signers = true;
            notify = "/run/agenix/autoUpdateNotify";
            emailTo = [ "leoank98@gmail.com" ];
            appManagementCheck = false;
          };
        };

        test-no-failed-assertions = {
          expr = {
            system = t.failedAssertions cfg;
            home = t.failedAssertions home;
          };
          expected = {
            system = [ ];
            home = [ ];
          };
        };
      };
    };
}
