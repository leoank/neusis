{
  pkgs,
  config,
  ...
}:
let
  pdf_viewer = if pkgs.stdenv.isDarwin then [ ] else [ pkgs.sioyek ]; # sioyek is not building on darwin
in
{
  home.packages =
    with pkgs;
    [
      xclip
      ripgrep
      lazygit
      gdu
      bottom
      python3
      nodejs_22
      deno
      cargo
      rustc
      cmake
      clang
      clang-tools
      unzip
      htop
      fd
      imagemagick
      zellij
      lua51Packages.lua
      lua51Packages.luarocks
      fzf
      ninja
      gnumake
      texliveFull
      wget
      rclone
      chafa
      ouch
      eza
      bat
      duf
      nix-output-monitor
    ]
    ++ pdf_viewer;

  programs.yazi = {
    enable = true;
    package = pkgs.yazi;
    keymap = {
      mgr.prepend_keymap = [
        {
          on = [ "T" ];
          run = "plugin max-preview";
          desc = "Maximize or restore preview";
        }
      ];

    };
    settings = {
      mgr.show_hidden = true;
      plugin.preloaders = [ ];
      preview = {
        max_width = 2000;
        max_height = 2000;
      };

    };
    enableZshIntegration = true;
    enableBashIntegration = true;
    plugins = {
      max-preview = ./yazi_img_max;
    };

  };

  programs.direnv = {
    #package = pkgs.unstable.direnv;
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-dash ];
  };
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableVteIntegration = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    history.path = "${config.xdg.dataHome}/zsh/history";
    history.size = 10000;
    oh-my-zsh = {
      enable = true;
      theme = "fino-time";
    };

    initContent = ''
      function update() {
        sudo nixos-rebuild switch --flake .#$1 -v
      }

      function darwin() {
        sudo darwin-rebuild switch --flake .#$1 -v
      }
    '';
  };
  programs.starship.enable = false;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--style full"
    ];
    fileWidgetOptions = [
      "--preview='bat --color=always {}'"
    ];
  };
  programs.television = {
    enable = true;
    package = pkgs.unstable.television;
    enableZshIntegration = false;
  };
  programs.nix-search-tv = {
    enable = true;
    enableTelevisionIntegration = true;
  };
  programs.nix-your-shell = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.nix-init = {
    enable = true;
    settings = {
      maintainers = [
        "ank"
      ];
    };
  };
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      decorations = {
        commit-decoration-style = "bold yellow box ul";
        file-decoration-style = "none";
        file-style = "bold yellow ul";
        hunk-header-decoration-style = "cyan box ul";
      };
      features = "side-by-side line-numbers decorations";
      syntax-theme = "dracula";
      plus-style = "syntax '#003800'";
      minus-style = "syntax '#3f0001'";
      line-numbers = {
        line-numbers-left-style = "cyan";
        line-numbers-right-style = "cyan";
        line-numbers-minus-style = "124";
        line-numbers-plus-style = "28";
      };
    };
  };
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
}
