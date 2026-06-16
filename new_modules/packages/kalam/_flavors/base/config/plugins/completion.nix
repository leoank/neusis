# Single completion stack: blink.cmp + LuaSnip as snippet engine.
# No nvim-cmp, no cmp-* sources. Language flavors add snippet
# collections by enabling further LuaSnip source paths.
#
# lspkind provides a comprehensive icon table for completion item
# kinds (function / variable / class / …). blink uses it via
# `appearance.kind_icons` below so the menu shows distinct icons
# instead of generic ones for less-common kinds.
{
  plugins = {
    luasnip.enable = true;
    lspkind.enable = true;

    blink-cmp = {
      enable = true;

      settings = {
        # Keymap presets:
        #   default       — Tab/S-Tab snippet-jump only; C-n/p for menu;
        #                   C-y accept; C-space toggle menu/docs.
        #   super-tab     — Tab/S-Tab navigate menu when open, jump in
        #                   snippet when in one, plain Tab otherwise.
        #                   C-y still accepts; Enter still inserts newline.
        #   enter         — Enter accepts (conflicts with newline; off).
        keymap.preset = "super-tab";

        appearance = {
          nerd_font_variant = "mono";
          # Replace blink's default kind icons with lspkind's
          # broader set (covers Constructor, Operator,
          # TypeParameter, and other niche LSP kinds with
          # distinct icons instead of a generic fallback).
          kind_icons.__raw = "require('lspkind').symbol_map";
        };

        completion = {
          accept.auto_brackets.enabled = true;
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 50;
          };
          ghost_text.enabled = true;
          list.selection.preselect = false;
          menu.draw.treesitter = [ "lsp" ];
        };

        signature.enabled = true;

        sources = {
          default = [ "lsp" "path" "snippets" "buffer" ];
        };

        snippets.preset = "luasnip";
      };
    };
  };
}
