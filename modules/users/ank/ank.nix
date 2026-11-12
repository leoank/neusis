{ self, inputs, ... }:
{
  # yajna.nix — the lab notebook CLI and its Neovim plugin, from
  # github:leoank/yajna (packages.yajna, packages.yajna-nvim). Its flake
  # pins nixpkgs-unstable, so point it at ours to dedup the closure.
  flake-file.inputs = {
    yajna = {
      url = "github:leoank/yajna";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };
  flake.neusis.users.ank.hmBundles.yajna =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      yajna = inputs.yajna.packages.${pkgs.stdenv.hostPlatform.system}.yajna;
      # yajna's dynamic zsh completion (subcommands, flags, the notebook's
      # IDs). The hook asks the `yajna` on PATH as you type, so generating it
      # once at build time stays right across updates and costs nothing at
      # shell start (REV-20261103-k6bx64 T1).
      zshCompletion = pkgs.runCommand "yajna-zsh-completion" { } ''
        COMPLETE=zsh ${lib.getExe yajna} > $out
      '';
    in
    {
      home.packages = [ yajna ];
      # initContent runs after compinit (oh-my-zsh.sh, or completionInit
      # without it), which compdef needs
      programs.zsh.initContent = lib.mkIf config.programs.zsh.enable "source ${zshCompletion}";
      # The per-user yajna config (ADR-0032 in yajna): the notebooks on this
      # home, by namespace, so `--in manthan` etc. work from anywhere; outside
      # any notebook, `yajna log` and `yajna todo` write to manthan. Pinned
      # entries win over yajna's own record of where it has run.
      xdg.configFile."yajna/config.toml".text = ''
        default = "manthan"

        [repos]
        manthan = "${config.home.homeDirectory}/workspace/chaos/manthan/main"
        saarthi = "${config.home.homeDirectory}/workspace/hub/leoank/rc2s2"
        yajna = "${config.home.homeDirectory}/workspace/chaos/yajna/main"
      '';
    };

  # Creating home manager feature bundles
  # hmBundles can be named anything and need not match one to one with a machine
  flake.neusis.users.ank.hmBundles.kalam-ide =
    { pkgs, ... }:
    {
      home.packages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.kalam
      ];
    };
  # neusis CLI — this flake's own package; added here (not in
  # _packages.nix) because `self` is only in scope at the flake-parts level.
  flake.neusis.users.ank.hmBundles.neusis-cli =
    { pkgs, ... }:
    {
      home.packages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.neusis
      ];
    };
  flake.neusis.users.ank.hmBundles.agent-harness =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        #self.homeModules.msgvault-sync
        self.homeModules.qmd-reindex
        self.homeModules.agent-harness
      ];

      #neusis.services.msgvault-sync.enable = true;
      neusis.services.qmd-reindex.enable = true;
      neusis.agent-harness = {
        enable = true;

        tools = {
          claude = {
            enable = true;
            # `claude` at a terminal runs under `saarthi run`, so the session can
            # be interrupted and killed from the phone, wherever this home also
            # runs the saarthi node daemon (the saarthi-node bundle: rogue today).
            saarthi.enable = config.services.saarthi-node.enable or false;
            # `settings` replaces the module default wholesale, so the
            # defaults are restated here. The yajna repo is a plugin
            # marketplace: its plugin brings the lab-notebook skill and
            # the /yajna:project commands. settings.json is read-only
            # under home-manager, so the plugin is declared here instead
            # of installed with `/plugin install`.
            settings = {
              hooks = {
                PostToolUse = [ ];
                PreToolUse = [ ];
              };
              includeCoAuthoredBy = false;
              permissions.defaultMode = "acceptEdits";
              theme = "dark";
              extraKnownMarketplaces.yajna = {
                source = {
                  source = "github";
                  repo = "leoank/yajna";
                };
                autoUpdate = true;
              };
              enabledPlugins."yajna@yajna" = true;
            };
            # Headless browser for developing/checking web pages (e.g.
            # the docs site). nixpkgs pins its own Chromium, so no
            # `npx` downloads; snapshots go to /tmp, not the repo.
            mcpServers.playwright = {
              command = lib.getExe pkgs.playwright-mcp;
              args = [
                "--headless"
                "--isolated"
                "--output-dir"
                "/tmp/playwright-mcp"
              ];
            };
          };
          opencode.enable = true;
          gemini.enable = true;
          antigravity.enable = true;
          pi.enable = true;
          hermes.enable = false;
        };
      };

    };

  flake.neusis.users.ank.hmBundles.terminal-life =
    { config, ... }:
    {
      imports = [
        self.homeModules.supercharged-git
        self.homeModules.supercharged-shell
        self.homeModules.terminal-velocity
        self.neusis.users.ank.hmBundles.zsh
      ];

      # enable git
      neusis.supercharged-git = {
        enable = true;
        userName = "Ankur Kumar";
        userEmail = "ank@leoank.me";
        signCommits = true;
        tools = {
          gh.enable = true;
          gh-dash.enable = false;
          mergiraf.enable = true;
          multi-account = { };
          act.enable = true;
          bootstrap-repos = {
            enable = true;
            location = "${config.home.homeDirectory}/workspace/repos";
            repos = [
              {
                url = "git@github.com:leoank/neusis";
                dest = "leoank/neusis";
              }
              {
                url = "git@github.com:nixos/nixpkgs";
                # Around ~3GB as of june 2026, so only cloning with depth 1
                extraGitArgs = [
                  "--depth"
                  "1"
                ];
              }
            ];
          };
          delta.enable = true;
          lazygit.enable = true;

          # pre-commit related
          pre-commit = {
            enable = true;
            autoInstall = false;
          };
          commitizen.enable = true;
          gitleaks.enable = true;
        };
      };

      # enable terminals and multiplexers
      neusis.terminal-velocity = {
        tools = {
          wezterm.enable = true;
          kitty = {
            enable = true;
            # kitty_mod is ctrl+shift; select_tab is kitty's built-in tab picker
            keybindings = {
              "kitty_mod+space" = "select_tab";
              "kitty_mod+a" = "goto_tab -1";
            };
          };
          tmux.enable = true;
        };
      };

      # enable shell utils
      neusis.supercharged-shell = {
        enable = true;
        tools = {
          yazi.enable = true;
          direnv.enable = true;
          fzf.enable = true;
          nix-your-shell.enable = true;
          nix-init = {
            enable = true;
            maintainers = [ "ank" ];
          };
          zoxide.enable = true;
          atuin.enable = true;
        };
      };
    };

  flake.neusis.users.ank.hmBundles.darwin-tools =
    { ... }:
    {
      imports = [
        self.homeModules.hammerspoon
        self.homeModules.mpd
        self.homeModules.rmpc
      ];

      neusis.hammerspoon.enable = true;
      neusis.mpd.enable = true;
      neusis.rmpc.enable = true;
    };

  # Browsers bundle — brave with ank's extension set.
  flake.neusis.users.ank.hmBundles.browsers =
    { ... }:
    {
      imports = [ self.homeModules.brave ];

      neusis.brave.enable = true;
    };

  # Secrets bundle — agenix-rekey home secrets (personal tokens).
  flake.neusis.users.ank.hmBundles.secrets =
    { config, lib, ... }:
    {
      imports = [ self.homeModules.secrets ];

      neusis.service.secrets = {
        enable = true;
        # ank's own key; a machine with a user key of its own sets it (secrets-curiosity).
        userPubkey = lib.mkDefault "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH40XzfXPtcTwJ8FHxHXCaEteylFOwtuw5TaY5CZ5NS ank@leoank.me";
        masterIdentities = [
          {
            # STRING path → read at `agenix rekey` time, never stored.
            identity = "/Users/ank/.ssh/id_ed25519";
            pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH40XzfXPtcTwJ8FHxHXCaEteylFOwtuw5TaY5CZ5NS ank@leoank.me";
          }
        ];
      };

      # Placeholder tokens — fill real values with
      # `agenix edit modules/secrets/ank/<name>.age`.
      age.secrets.ghauthToken.rekeyFile = ../../secrets/ank/ghauthToken.age;
      age.secrets.atuinToken.rekeyFile = ../../secrets/ank/atuinToken.age;

      # Oracle Cloud operator credentials for the terranix stacks
      # (docs/cloud-terranix-plan.md, "Operator prerequisites"): the API
      # signing key and its ~/.oci/config profile for the provider, and
      # the TF_VAR_* env file the stack wrapper sources (compartment
      # OCID, state passphrase). Placeholders until filled the same way.
      age.secrets.ociApiKey = {
        rekeyFile = ../../secrets/ank/ociApiKey.age;
        path = "${config.home.homeDirectory}/.oci/neusis_api_key.pem";
      };
      age.secrets.ociConfig = {
        rekeyFile = ../../secrets/ank/ociConfig.age;
        path = "${config.home.homeDirectory}/.oci/config";
      };
      age.secrets.ociTfEnv = {
        rekeyFile = ../../secrets/ank/ociTfEnv.age;
        path = "${config.home.homeDirectory}/.config/neusis/tf.env";
      };
    };

  # saarthi node — the daemon that observes and gates this machine's Claude Code
  # sessions and streams them to the hub on ghost001. Attached to rogue only
  # (it reads ~/.claude and watches the owner's live sessions). The module comes
  # from the saarthi flake (saarthi ADR-0041) and puts `saarthi` on PATH for
  # `saarthi run`, `saarthi node hooks` and `saarthi ctl`.
  flake.neusis.users.ank.hmBundles.saarthi-node =
    {
      config,
      inputs,
      ...
    }:
    {
      imports = [ inputs.saarthi.homeModules.saarthi-node ];

      # Explicit stable path: the default darwin agenix path is under
      # `$(getconf DARWIN_USER_TEMP_DIR)`, which a quoted launchd argument would
      # not expand (same reason the oci* secrets above pin a path).
      age.secrets.saarthiRogueNodeToken = {
        rekeyFile = ../../secrets/ank/saarthiRogueNodeToken.age;
        path = "${config.home.homeDirectory}/.config/saarthi/node-token";
      };
      # The Claude login of sandboxed sessions: a long-lived token from
      # `claude setup-token`, which the node passes in as CLAUDE_CODE_OAUTH_TOKEN,
      # so the keychain login stays out of the sandbox (saarthi ADR-0038).
      age.secrets.saarthiSandboxClaudeToken = {
        rekeyFile = ../../secrets/ank/saarthiSandboxClaudeToken.age;
        path = "${config.home.homeDirectory}/.config/saarthi/sandbox-claude-token";
      };
      # `saarthi ctl` and `saarthi tui` on this machine: the hub and this client's token
      # (`rogue-ctl` in the hub's saarthiClientTokens), read from ctl.toml.
      age.secrets.saarthiRogueClientToken = {
        rekeyFile = ../../secrets/ank/saarthiRogueClientToken.age;
        path = "${config.home.homeDirectory}/.config/saarthi/client-token";
      };
      xdg.configFile."saarthi/ctl.toml".text = ''
        hub = "http://ghost001:7700"
        token_file = "${config.age.secrets.saarthiRogueClientToken.path}"
      '';

      services.saarthi-node = {
        enable = true;
        hub = "http://ghost001:7700";
        tokenFile = config.age.secrets.saarthiRogueNodeToken.path;
        name = "rogue";
        # The saarthi live checks start throwaway sessions here; the live hub must not
        # list them or push their turns to the phone (saarthi ADR-0028).
        ignoreCwd = [ "*/target/live-work-*" ];
        # Hold the machine out of idle sleep while a session is busy, so a turn
        # finishes and the hub link holds when the screen turns off (saarthi ADR-0031).
        keepAwake = true;
        # The phone may start sessions in any repo under ~/workspace (saarthi
        # ADR-0034). `claude` is the login shell's, the profile's wrapper with the
        # plugins, which runs claude directly when its input is not a terminal.
        spawnRoots = [ "${config.home.homeDirectory}/workspace" ];
        # The account's rate limits as health, the access token read from the keychain,
        # never written (saarthi ADR-0030; checked on this login in EXP-20261025-25f6vm).
        claudeUsage = true;
        # A confined way to start a session, offered on the app's New session
        # (saarthi ADR-0038, checked live in saarthi's AGS-20261107-413qp0): seatbelt
        # through mxc, its own Claude config under the state directory, all egress,
        # the nix store and daemon, the profile's tools, git identity, the SSH
        # agent (push without the keys), and CLAUDE.md, skills, commands and agents.
        profiles.sandbox = {
          backend = "seatbelt";
          description = "Confined: the working directory, the nix store, git identity and the SSH agent";
          state_dir = "~/.local/state/saarthi/sandbox";
          token_file = config.age.secrets.saarthiSandboxClaudeToken.path;
          path = [
            "~/.nix-profile/bin"
            "/etc/profiles/per-user/${config.home.username}/bin"
            "/run/current-system/sw/bin"
            "/nix/var/nix/profiles/default/bin"
          ];
          readonly = [
            "/nix/var/nix/profiles"
            "/nix/var/nix/gcroots"
            "/private/etc/profiles"
            "/private/etc/nix"
            "/private/etc/static"
            "/private/var/run/current-system"
            "~/.nix-profile"
            "~/.local/state/nix/profiles"
            "~/.config/git"
            "~/.ssh/config"
            "~/.ssh/known_hosts"
          ];
          claude_files = [
            "CLAUDE.md"
            "skills"
            "commands"
            "agents"
          ];
          env = {
            GIT_CONFIG_GLOBAL = "~/.config/git/config";
            SSH_AUTH_SOCK = "~/.bitwarden-ssh-agent.sock";
          };
        };
      };
    };

  # saarthi node on curiosity (the N1X live disk), as on rogue minus what is macOS-only: no
  # seatbelt sandbox profile, no keepAwake (documented as `caffeinate` on Darwin). The module
  # puts `saarthi` on PATH.
  flake.neusis.users.ank.hmBundles.saarthi-node-curiosity =
    {
      config,
      inputs,
      ...
    }:
    {
      imports = [ inputs.saarthi.homeModules.saarthi-node ];

      # Home-manager secrets (secrets-curiosity); the hub's node tokens file has the same
      # token under `curiosity`, and `curiosity-ctl` is in its client tokens.
      age.secrets.saarthiCuriosityNodeToken.rekeyFile = ../../secrets/ank/saarthiCuriosityNodeToken.age;
      age.secrets.saarthiCuriosityClientToken.rekeyFile = ../../secrets/ank/saarthiCuriosityClientToken.age;

      services.saarthi-node = {
        enable = true;
        hub = "http://ghost001:7700";
        tokenFile = config.age.secrets.saarthiCuriosityNodeToken.path;
        name = "curiosity";
        ignoreCwd = [ "*/target/live-work-*" ];
        spawnRoots = [ "${config.home.homeDirectory}/workspace" ];
        claudeUsage = true;
      };
      # The token is decrypted by the agenix user unit; start after it.
      systemd.user.services.saarthi-node.Unit = {
        Wants = [ "agenix.service" ];
        After = [ "agenix.service" ];
      };
      # `saarthi ctl` and `saarthi tui`: the hub and this machine's client token.
      xdg.configFile."saarthi/ctl.toml".text = ''
        hub = "http://ghost001:7700"
        token_file = "${config.age.secrets.saarthiCuriosityClientToken.path}"
      '';
    };

  # ank's home secrets on curiosity: decrypted with curiosity's own user key, a system secret
  # owned by ank (machines/curiosity.nix) linked as ~/.ssh/id_ed25519 (agenix's default
  # identity, and the key ssh logs in to his other machines with: it is in the registry's
  # sshKeys). Rekeyed to that key under rekeyed/hm/ank-curiosity, apart from rogue's. Decrypted
  # into ~/.config/agenix so the paths are fixed (the default lives under $XDG_RUNTIME_DIR).
  flake.neusis.users.ank.hmBundles.secrets-curiosity =
    { config, lib, ... }:
    {
      imports = [ self.neusis.users.ank.hmBundles.secrets ];

      neusis.service.secrets.userPubkey = lib.fileContents ../../secrets/ank/curiosityUserKey.pub;
      age.rekey.localStorageDir = ../../secrets/rekeyed + "/hm/ank-curiosity";
      age.secretsDir = "${config.home.homeDirectory}/.config/agenix";

      home.file.".ssh/id_ed25519".source = config.lib.file.mkOutOfStoreSymlink "/run/agenix/curiosityUserKey";
      home.file.".ssh/id_ed25519.pub".source = ../../secrets/ank/curiosityUserKey.pub;
    };

  # Commits on curiosity are signed with curiosity's own key, a home secret (secrets-curiosity);
  # the public half is a signing key on ank's GitHub account and in curiosity's comin signers.
  flake.neusis.users.ank.hmBundles.git-signing-curiosity =
    { config, ... }:
    {
      age.secrets.curiositySigningKey = {
        rekeyFile = ../../secrets/ank/curiositySigningKey.age;
        generator.script = self.neusis.lib.agenixGenerators.sshKey "ank@leoank.me curiosity";
      };
      neusis.supercharged-git.signingKey = config.age.secrets.curiositySigningKey.path;
    };

  # ssh to GitHub from curiosity with curiosity's own key, a home secret (secrets-curiosity) and
  # an authentication key on ank's GitHub account; IdentitiesOnly so no other key is offered.
  flake.neusis.users.ank.hmBundles.github-ssh-curiosity =
    { config, ... }:
    {
      age.secrets.curiosityGithubSshKey = {
        rekeyFile = ../../secrets/ank/curiosityGithubSshKey.age;
        generator.script = self.neusis.lib.agenixGenerators.sshKey "ank@leoank.me curiosity github";
      };
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."github.com" = {
          IdentityFile = config.age.secrets.curiosityGithubSshKey.path;
          IdentitiesOnly = true;
        };
      };
    };

  # gh on curiosity logs in with the ghauthToken home secret (secrets-curiosity), read by gh
  # itself at each run: a login that survives the live disk's reboots, without the token in
  # every shell's environment. git's https credential helper goes through gh too.
  flake.neusis.users.ank.hmBundles.gh-curiosity =
    { config, pkgs, ... }:
    let
      token = config.age.secrets.ghauthToken.path;
    in
    {
      programs.gh.package = pkgs.symlinkJoin {
        name = "gh-${pkgs.gh.version}";
        inherit (pkgs.gh) version meta;
        paths = [ pkgs.gh ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/gh --run '
            if [ -z "''${GH_TOKEN-}" ] && [ -r ${token} ]; then
              GH_TOKEN=$(<${token}); export GH_TOKEN
            fi'
        '';
      };
    };

  # saarthi node on ghost001, the hub's own host: headless sessions in ~/workspace there,
  # under the Claude account picked or the node's default set from the app (ghost has no
  # Claude login of its own, so no claudeUsage). A systemd user service, with linger on
  # (machines/ghost001.nix).
  flake.neusis.users.ank.hmBundles.saarthi-node-ghost001 =
    {
      config,
      inputs,
      ...
    }:
    {
      imports = [ inputs.saarthi.homeModules.saarthi-node ];

      services.saarthi-node = {
        enable = true;
        hub = "http://127.0.0.1:7700";
        # A system secret of ghost001's, owned by ank (machines/ghost001.nix); the hub's
        # node tokens file has the same token under `ghost001`.
        tokenFile = "/run/agenix/saarthiGhost001NodeToken";
        name = "ghost001";
        ignoreCwd = [ "*/target/live-work-*" ];
        spawnRoots = [ "${config.home.homeDirectory}/workspace" ];
      };
      # `saarthi ctl` and `saarthi tui`: the hub on this host and this machine's client
      # token, a system secret owned by ank (machines/ghost001.nix).
      xdg.configFile."saarthi/ctl.toml".text = ''
        hub = "http://127.0.0.1:7700"
        token_file = "/run/agenix/saarthiGhost001ClientToken"
      '';
    };

  # Configuring user for neusisOS
  flake.neusis.users.ank.neusisOS = {
    username = "ank";
    fullName = "Ankur Kumar";
    shell = "zsh";
    # These keys will be used for configuring - git, ssh, secrets ...
    sshKeys = [
      ./id_rsa.pub
      ./id_ed25519.pub
      ./id2_ed25519.pub
      # curiosity's user key (machines/curiosity.nix), so ank logs in from there.
      ../../secrets/ank/curiosityUserKey.pub
    ];
    # Mapping hm feature bundles to machines
    machineToBundlesMap = {
      rogue = [
        self.neusis.features.agnostic.nix-pkgs
        self.neusis.features.hm.mac-app-util
        self.neusis.users.ank.hmBundles.kalam-ide
        self.neusis.users.ank.hmBundles.neusis-cli
        self.neusis.users.ank.hmBundles.yajna
        self.neusis.users.ank.hmBundles.terminal-life
        self.neusis.users.ank.hmBundles.agent-harness
        self.neusis.users.ank.hmBundles.saarthi-node
        self.neusis.users.ank.hmBundles.darwin-tools
        self.neusis.users.ank.hmBundles.theming
        self.neusis.users.ank.hmBundles.browsers
        self.neusis.users.ank.hmBundles.casks
        self.neusis.users.ank.hmBundles.secrets
        self.neusis.users.ank.hmBundles.mail
        ./_packages.nix
      ];
      # Headless cloud host: shell/editor/CLI bundles only — no GUI, casks
      # or personal tokens (the `secrets` bundle needs ank's private key).
      # (no `yajna` for now: 0.7.1 fails to build for aarch64-linux)
      ghost001 = [
        self.neusis.features.agnostic.nix-pkgs
        self.neusis.users.ank.hmBundles.kalam-ide
        self.neusis.users.ank.hmBundles.neusis-cli
        self.neusis.users.ank.hmBundles.terminal-life
        # Claude Code and the hooks for the saarthi node's sessions.
        self.neusis.users.ank.hmBundles.agent-harness
        self.neusis.users.ank.hmBundles.saarthi-node-ghost001
      ];
      # N1X laptop live disk (GNOME): the workstation bundles for sessions on the machine. Its
      # home secrets decrypt with curiosity's own user key (secrets-curiosity), not ank's.
      curiosity = [
        self.neusis.features.agnostic.nix-pkgs
        self.neusis.users.ank.hmBundles.kalam-ide
        self.neusis.users.ank.hmBundles.neusis-cli
        self.neusis.users.ank.hmBundles.yajna
        self.neusis.users.ank.hmBundles.terminal-life
        self.neusis.users.ank.hmBundles.secrets-curiosity
        self.neusis.users.ank.hmBundles.git-signing-curiosity
        self.neusis.users.ank.hmBundles.gh-curiosity
        self.neusis.users.ank.hmBundles.github-ssh-curiosity
        self.neusis.users.ank.hmBundles.agent-harness
        self.neusis.users.ank.hmBundles.saarthi-node-curiosity
      ];
    };
  };
}
