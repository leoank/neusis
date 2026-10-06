{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  name = "Jonne Rietdijk";
  user = "jrietdij";
  email = "jrietdij@broadinstitute.org";

  # Create pkgs-unstable with unfree allowed
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  home = {
    username = "jrietdij";
    homeDirectory = "/home/jrietdij";

    packages = with pkgs; [
      # Data tools
      duckdb
      jq
      yq-go # YAML processor
      sqlite

      # Development tools
      gh # GitHub CLI
      lazygit # Terminal UI for git
      delta # Better git diff
      bat # Better cat with syntax highlighting
      eza # Modern ls replacement
      fd # Better find
      ripgrep # Fast grep
      fzf # Fuzzy finder
      just # Command runner

      # System monitoring
      htop
      btop # Better htop
      ncdu # Disk usage analyzer
      duf # Better df
      iftop # Network bandwidth monitor

      # Network tools
      curl
      wget
      httpie # Better curl for APIs
      mtr # Network diagnostic tool

      # Cloud and containers
      awscli2
      docker
      docker-compose
      rclone
      s5cmd
      nodePackages.aws-cdk # AWS CDK CLI

      # File management
      tree
      ranger # Terminal file manager
      yazi # Modern terminal file manager

      # Text processing
      neovim

      # Archive tools
      unzip
      zip
      p7zip

      # Python tools
      python3
      virtualenv
      uv
      pixi

      # Shell enhancements
      atuin # Better shell history
      tmux # Terminal multiplexer

      # Misc utilities
      tldr # Simplified man pages
      pkgs.unstable.direnv # Directory-specific environments
      starship # Modern shell prompt
      parallel # GNU parallel
      ffmpeg
      pandoc
      graphviz

      # Linting and formatting
      nixpkgs-fmt # Nix formatter
      ruff # Python linter
      pre-commit
    ];
  };

  programs = {
    # zoxide for smart directory jumping (faster than z-lua)
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # Zsh configuration
    zsh = {
      enable = true;
      autocd = false;
      # Override vi-mode from editors.nix - disable it
      plugins = [ ];

      initContent = lib.mkAfter ''
        # Use emacs keybindings, not vi (override editors.nix)
        bindkey -e

        # Disable automatic menu completion that interferes with atuin
        unsetopt auto_menu

        if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
          . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
          . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
        fi

        # Define variables for directories
        export PATH=$HOME/.pnpm-packages/bin:$HOME/.pnpm-packages:$PATH

        export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
        export PATH=$HOME/.local/share/bin:$PATH

        # Remove history data we don't want to see
        export HISTIGNORE="pwd:ls:cd"

        # Neovim is my editor
        export EDITOR="nvim"
        export VISUAL="nvim"

        # nix shortcuts
        shell() {
            nix-shell '<nixpkgs>' -A "$1"
        }

        # Use difftastic, syntax-aware diffing
        # alias diff=difft

        alias ll="ls -l"

        # Always color ls and group directories
        alias ls='ls --color=auto'
      '';
    };

    # Git configuration
    git = {
      enable = true;
      ignores = [ "*.swp" ];
      lfs.enable = true;
      settings = {
        user = {
          name = name;
          email = email;
        };
        init.defaultBranch = "main";
        core = {
          editor = "nvim";
          autocrlf = "input";
        };
        pull.rebase = true;
        rebase.autoStash = true;
      };
    };

    # Starship prompt
    starship = {
      enable = lib.mkForce true;
    };

    # Atuin for better shell history
    atuin = {
      enable = lib.mkForce true;
      enableZshIntegration = true;
    };

    # SSH configuration
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [
        "${config.home.homeDirectory}/.ssh/config_external"
      ];
      matchBlocks."*" = {
        extraOptions = {
          "AddKeysToAgent" = "yes";
          "IdentityFile" = "~/.ssh/id_rsa";
        };
      };
    };
  };

  # SSH Agent configuration - automatically manages encrypted SSH keys
  services.ssh-agent.enable = true;
}
