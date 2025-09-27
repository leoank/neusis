{ config, pkgs, lib, inputs, ... }:

let 
  name = "Shantanu Singh";
  user = "shsingh";
  email = "shsingh@broadinstitute.org";
  
  # Create pkgs-unstable with unfree allowed
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in
{
  home = {
    username = "shsingh";
    homeDirectory = "/home/shsingh";

    packages = with pkgs; [
      # Data tools
      duckdb
      jq
      yq-go  # YAML processor
      sqlite
      
      # Development tools
      gh  # GitHub CLI
      lazygit  # Terminal UI for git
      delta  # Better git diff
      bat  # Better cat with syntax highlighting
      eza  # Modern ls replacement
      fd  # Better find
      ripgrep  # Fast grep
      fzf  # Fuzzy finder
      just  # Command runner
      
      # System monitoring
      htop
      btop  # Better htop
      ncdu  # Disk usage analyzer
      duf  # Better df
      iftop  # Network bandwidth monitor
      
      # Network tools
      curl
      wget
      httpie  # Better curl for APIs
      mtr  # Network diagnostic tool
      
      # Cloud and containers
      awscli2
      docker
      docker-compose
      rclone
      s5cmd
      nodePackages.aws-cdk  # AWS CDK CLI
      
      # File management
      tree
      ranger  # Terminal file manager
      yazi  # Modern terminal file manager
      
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
      atuin  # Better shell history
      
      # Misc utilities
      tldr  # Simplified man pages
      direnv  # Directory-specific environments
      starship  # Modern shell prompt
      parallel  # GNU parallel
      ffmpeg
      pandoc
      graphviz
      
      # Linting and formatting
      nixpkgs-fmt  # Nix formatter
      ruff  # Python linter
      pre-commit
      
      # AI tools
      pkgs-unstable.claude-code  # Claude Code CLI (latest from unstable)
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
      plugins = [];

      initContent = lib.mkAfter ''
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
      userName = name;
      userEmail = email;
      lfs = {
        enable = true;
      };
      extraConfig = {
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
      includes = [
        "${config.home.homeDirectory}/.ssh/config_external"
      ];
    };
  };

  # SSH Agent configuration - automatically manages encrypted SSH keys
  services.ssh-agent.enable = true;

  # Auto-add default SSH key on shell startup (prompts for passphrase once per session)
  programs.zsh.initExtra = ''
    # Add SSH key to agent if not already added
    if [ -f ~/.ssh/id_ed25519 ]; then
      if ! ssh-add -l &>/dev/null || ! ssh-add -l | grep -q "id_ed25519"; then
        ssh-add ~/.ssh/id_ed25519 2>/dev/null
      fi
    fi
  '';
}
