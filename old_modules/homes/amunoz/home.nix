{ pkgs, ... }:
{
  imports = [
    ./configs/opencode.nix
  ];

  home = {
    username = "amunoz";
    homeDirectory = "/home/amunoz";

    packages = with pkgs; [
      autoconf
      automake
      autotools-language-server # make
      bc # calculator
      btop-cuda # nicer top
      cargo # rust packages
      clang # c language
      clang-tools # tools for c language
      claude-code
      cmake # c compiler
      devenv
      difftastic # better diffs
      pkgs.unstable.direnv # Per-project isolated environment
      dua # better du
      duckdb
      dust # interactive du in tust
      emacs
      emacs-all-the-icons-fonts
      fd # faster find
      ffmpeg # video processing needs
      fontconfig # Needed for napari
      fzf # fuzzy finder
      gawk # Main awk
      gemini-cli
      gemini-cli
      git
      gnumake # Necessary for emacs' vterm
      gnumeric
      gnuplot # no-fuss plotting
      gnused # The one and only sed
      gnutar # The one and only tar
      gprof2dot
      graphicsmagick # imagemagick (+speed, -features) alternative
      graphviz
      haskellPackages.xml-to-json-fast
      http-server
      hugo # blogging
      imagemagick # image processing
      inkscape # Graphics editing
      jq # process json
      killall # kill all the processes by name
      lemminx # xml
      libtool # Necessary for emacs' vterm
      lsof # Files and their processes
      ltex-ls # language tool LSP for latex and org-mode
      luajitPackages.fennel # lua in fennel
      magic-wormhole # easy sharing
      marksman # markdown
      mawk # faster awk
      mermaid-cli # text to diagrams
      nil # Nix
      nix-index # locate packages that provide a certain file
      nix-output-monitor
      nix-search-cli # find nix packages
      nixfmt-rfc-style # Nix formatting (for nixpkgs)
      nixfmt-tree # Format entire directories of nix
      nodePackages.bash-language-server # bash
      opencode
      pandoc # Convert between formats
      parallel # GNU parallel
      pdftk
      pigz # threaded gunzip
      podman # for container needs
      ps # processes
      qrtool # encode and decode qr codes
      ripgrep # faster grep in rust
      rsync # sync data
      ruff # python
      rustc # rust compiler
      screen # ssh in and out of a server
      semgrep # generalist semantic grep
      shellcheck
      shfmt
      tldr # quick explanations
      tree
      unzip # extract zips
      uv
      wget # fetch stuff
      xclip # clipboard manipulation tool
      yaml-language-server # yaml
      zip
    ];
  };

  programs.fish = {
    enable = true;
    plugins = [
      # Enable a plugin (here grc for colorized command output) from nixpkgs
      {
        name = "pure";
        src = pkgs.fishPlugins.pure.src;
      }
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair.src;
      }
      # {
      #   name = "fishbang";
      #   src = pkgs.fishPlugins.fishbang.src;
      # }
      {
        name = "fish-you-should-use";
        src = pkgs.fishPlugins.fish-you-should-use.src;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge.src;
      }
      {
        name = "async-prompt";
        src = pkgs.fishPlugins.async-prompt.src;
      }
    ];
    interactiveShellInit = ''
      set --universal pure_enable_nixdevshell true
    '';
  };
  programs.atuin =
    let
      atuin_daemon_p = if pkgs.stdenv.isLinux then true else false;
    in
    {
      enable = true;
      # package = pkgs.stable.atuin;
      enableFishIntegration = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
      settings = {
        auto_sync = true;
        sync_frequency = "5m";
        sync_address = "https://api.atuin.sh";
        search_mode = "prefix";
        daemon = {
          enabled = atuin_daemon_p;
          socket_path = "/home/amunoz/.local/share/atuin/atuin.sock";
        };
        # // atuin_key_path;
      };
    };

}
