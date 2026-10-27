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
    { config, pkgs, ... }:
    {
      home.packages = [
        inputs.yajna.packages.${pkgs.stdenv.hostPlatform.system}.yajna
      ];
      # The per-user yajna config (ADR-0032 in yajna): the notebooks on this
      # home, by namespace, so `--in manthan` etc. work from anywhere; outside
      # any notebook, `yajna log` and `yajna todo` write to manthan. Pinned
      # entries win over yajna's own record of where it has run.
      xdg.configFile."yajna/config.toml".text = ''
        default = "manthan"

        [repos]
        manthan = "${config.home.homeDirectory}/workspace/chaos/manthan/main"
        rc2s2 = "${config.home.homeDirectory}/workspace/hub/leoank/rc2s2"
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
    { lib, pkgs, ... }:
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
          kitty.enable = true;
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
    { config, ... }:
    {
      imports = [ self.homeModules.secrets ];

      neusis.service.secrets = {
        enable = true;
        userPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFH40XzfXPtcTwJ8FHxHXCaEteylFOwtuw5TaY5CZ5NS ank@leoank.me";
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

  # rc2s2 node — the daemon that observes and gates this machine's Claude Code
  # sessions and streams them to the hub on ghost001. Attached to rogue only
  # (it reads ~/.claude and watches the owner's live sessions).
  flake.neusis.users.ank.hmBundles.rc2s2-node =
    {
      config,
      pkgs,
      inputs,
      ...
    }:
    {
      imports = [ self.homeModules.rc2s2-node ];

      # Explicit stable path: the default darwin agenix path is under
      # `$(getconf DARWIN_USER_TEMP_DIR)`, which a quoted launchd argument would
      # not expand (same reason the oci* secrets above pin a path).
      age.secrets.rc2s2RogueNodeToken = {
        rekeyFile = ../../secrets/ank/rc2s2RogueNodeToken.age;
        path = "${config.home.homeDirectory}/.config/rc2s2/node-token";
      };

      neusis.services.rc2s2-node = {
        enable = true;
        hub = "http://ghost001:7700";
        tokenFile = config.age.secrets.rc2s2RogueNodeToken.path;
        name = "rogue";
        # The rc2s2 live checks start throwaway sessions here; the live hub must not
        # list them or push their turns to the phone (rc2s2 ADR-0028).
        ignoreCwd = [ "*/target/live-work-*" ];
        # Hold the machine out of idle sleep while a session is busy, so a turn
        # finishes and the hub link holds when the screen turns off (rc2s2 ADR-0031).
        keepAwake = true;
        # The account's rate limits as health, the access token read from the keychain,
        # never written (rc2s2 ADR-0030; checked on this login in EXP-20261025-25f6vm).
        claudeUsage = true;
      };

      # rc2s2 on PATH for `rc2s2 run` (the PTY wrapper), `rc2s2 node hooks`
      # and `rc2s2 ctl`.
      home.packages = [ inputs.rc2s2.packages.${pkgs.stdenv.hostPlatform.system}.rc2s2 ];
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
        self.neusis.users.ank.hmBundles.rc2s2-node
        self.neusis.users.ank.hmBundles.darwin-tools
        self.neusis.users.ank.hmBundles.theming
        self.neusis.users.ank.hmBundles.browsers
        self.neusis.users.ank.hmBundles.casks
        self.neusis.users.ank.hmBundles.secrets
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
      ];
    };
  };
}
