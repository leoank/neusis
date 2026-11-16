# Neusis supercharged-shell home-manager module.
# Umbrella for an opinionated terminal/shell developer toolkit:
# file manager (yazi), env auto-loading (direnv), fuzzy pickers
# (fzf, television), nix-aware helpers (nix-search-tv,
# nix-your-shell, nix-init), a smarter cd (zoxide), and syncable
# shell history (atuin).
#
# Importing this module brings in every tool sub-module so the
# `neusis.supercharged-shell.tools.<name>.enable` options are
# declared. Each tool defaults to disabled — enable them piecemeal.
#
# Setting `neusis.supercharged-shell.enable = true` adds a curated
# bundle of CLI utilities and dev tools (eza, bat, ripgrep, htop,
# language toolchains, …) to `home.packages`. Use `extraPackages`
# to extend, `toolchains.enable = false` to leave out the toolchains
# and TeX (most of its size), or skip the umbrella `enable` if you
# only want the tool sub-modules.
#
# Sister module to `supercharged-git` and `terminal-velocity`: same
# opt-in shape, no overlap.
{ self, ... }:
{
  flake.homeModules.supercharged-shell =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.neusis.supercharged-shell;

      # Curated CLI bundle — installed whenever the umbrella's
      # `enable` is true. Things already owned by another umbrella
      # (lazygit → supercharged-git, fzf/yazi → individual tool
      # sub-modules in this umbrella, zellij → terminal-velocity)
      # are intentionally omitted to avoid duplicate package paths.
      defaultPackages = with pkgs; [
        # General-purpose CLI utilities.
        bat
        bottom
        chafa
        comma
        duf
        eza
        fd
        gdu
        htop
        imagemagick
        nix-output-monitor
        ouch
        rclone
        ripgrep
        unzip
        wget
        xclip

        # Lua (used by yazi plugins, wezterm config, neovim configs).
        lua51Packages.lua
        lua51Packages.luarocks
      ];

      # Programming / build toolchains and TeX: most of the bundle's size
      # (texliveFull alone is ~6 GB), so `toolchains.enable` can leave them out.
      toolchainPackages =
        with pkgs;
        [
          cargo
          clang
          clang-tools
          cmake
          deno
          gnumake
          ninja
          nodejs_22
          python3
          rustc
          texliveFull
        ]
        # Linux-only PDF viewer (sioyek doesn't build on Darwin).
        ++ lib.optionals (!pkgs.stdenv.isDarwin) [ pkgs.sioyek ];
    in
    {
      imports = [
        self.homeModules.supercharged-shell-yazi
        self.homeModules.supercharged-shell-direnv
        self.homeModules.supercharged-shell-fzf
        self.homeModules.supercharged-shell-television
        self.homeModules.supercharged-shell-nix-search-tv
        self.homeModules.supercharged-shell-nix-your-shell
        self.homeModules.supercharged-shell-nix-init
        self.homeModules.supercharged-shell-zoxide
        self.homeModules.supercharged-shell-atuin
      ];

      options.neusis.supercharged-shell = {
        enable = lib.mkEnableOption ''
          neusis-curated bundle of CLI utilities and dev tools (eza,
          bat, ripgrep, htop, fd, comma, language toolchains, …).
          Independent of the per-tool `tools.<x>.enable` flags — you
          can enable individual tool sub-modules without the bundle
          and vice versa
        '';

        toolchains.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether the bundle includes the language toolchains and TeX
            (cargo, rustc, clang, clang-tools, cmake, deno, gnumake,
            ninja, nodejs_22, python3, texliveFull) and, on Linux, the
            sioyek PDF viewer. Turn off on hosts with little disk, such
            as servers: they are most of the bundle's size.
          '';
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "with pkgs; [ jq yq tealdeer ]";
          description = ''
            Extra packages appended to the default bundle when the
            umbrella's `enable` is on. Useful for per-host or
            per-user additions without forking the bundle.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages =
          defaultPackages ++ lib.optionals cfg.toolchains.enable toolchainPackages ++ cfg.extraPackages;
      };
    };
}
