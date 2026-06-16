{ self, ... }:
{
  # Creating home manager feature bundles
  # hmBundles can be named anything and need not match one to one with a machine
  flake.neusis.users.ank.hmBundles.kalam-ide =
    { pkgs, ... }:
    {
      home.packages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.kalam
      ];
    };
  flake.neusis.users.ank.hmBundles.agent-harness =
    { ... }:
    {
      imports = [
        self.homeModules.msgvault-sync
        self.homeModules.qmd-reindex
        self.homeModules.agent-harness
      ];

      neusis.services.msgvault-sync.enable = true;
      neusis.services.qmd-reindex.enable = true;
      neusis.agent-harness = {
        enable = true;

        tools = {
          claude.enable = true;
          opencode.enable = true;
          gemini.enable = true;
          pi.enable = true;
          hermes.enable = true;
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
        self.neusis.users.ank.hmBundles.kalam-ide
        self.neusis.users.ank.hmBundles.terminal-life
        self.neusis.users.ank.hmBundles.agent-harness
        self.neusis.users.ank.hmBundles.darwin-tools
        self.neusis.users.ank.hmBundles.theming
        self.neusis.users.ank.hmBundles.browsers
        ./_packages.nix
      ];
    };
  };
}
