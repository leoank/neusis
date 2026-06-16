# ank's theming bundle — stylix system theme + wallpaper.
#
# Centralized colour scheme + fonts + image. stylix wires the
# scheme into anything that lists itself in `targets` (here:
# wezterm). Other consumers (kitty, lualine via catppuccin, gtk,
# etc.) opt in by enabling their `targets.X.enable`.
#
# Wallpaper lives in `_assets/wallpaper.jpg` — the `_` prefix
# keeps `import-tree` from interpreting it as a flake-parts module.
{ self, ... }:
{
  flake-file.inputs.stylix = {
    url = "github:danth/stylix/release-25.11";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.neusis.users.ank.hmBundles.theming =
    {
      pkgs,
      inputs,
      ...
    }:
    {
      imports = [ inputs.stylix.homeModules.stylix ];

      stylix = {
        enable = true;

        # Terminal opacity at the system level — wezterm honours this
        # via the target below; kitty manages its own opacity in our
        # terminal-velocity tool config if you want translucency there.
        opacity.terminal = 0.8;

        # Which apps stylix should style. Disable the desktop-env
        # bits because rogue is darwin — no gnome/gtk.
        targets = {
          gnome.enable = false;
          gtk.enable = false;
          wezterm.enable = true;
          # tmux off — let our tmux config own its colors.
          tmux.enable = false;
        };

        # base16 colour scheme. "evenok-dark" from nixpkgs's
        # base16-schemes — feels cooler than catppuccin while
        # still working with most syntax themes.
        base16Scheme = "${pkgs.base16-schemes}/share/themes/evenok-dark.yaml";

        fonts = {
          monospace = {
            package = pkgs.nerd-fonts.iosevka-term;
            name = "IosevkaTerm Nerd Font Mono";
          };
          sansSerif = {
            package = pkgs.nerd-fonts.iosevka;
            name = "Iosevka Nerd Font";
          };
          serif = {
            package = pkgs.nerd-fonts.iosevka-term-slab;
            name = "Iosevka Nerd Font";
          };
          emoji = {
            package = pkgs.noto-fonts-color-emoji;
            name = "Noto Color Emoji";
          };
          sizes = {
            applications = 13;
            desktop = 13;
            popups = 13;
            terminal = 13;
          };
        };

        polarity = "dark";
        image = ./_assets/wallpaper.jpg;
      };
    };
}
