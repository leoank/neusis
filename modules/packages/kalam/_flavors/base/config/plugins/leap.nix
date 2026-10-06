# leap.nvim — type two characters, jump to a labeled match on
# screen. Replaces `/` and `f`-spamming for "I see the spot,
# just take me there" moves.
#
# Bound to `s` (forward) / `S` (backward). The default `gs`
# binding is left off so mini.surround can keep the `gs*`
# prefix (see mini.nix).
{
  plugins.leap.enable = true;
  # leap no longer ships default mappings — we add our own below.
  # The natural `gs` default (cross-window leap) is intentionally
  # omitted so mini.surround can own the `gs*` prefix.

  keymaps = [
    # Bidirectional leap — labels every match on screen in BOTH
    # directions from the cursor in the CURRENT window.
    {
      mode = [ "n" "x" "o" ];
      key = "s";
      action.__raw = ''
        function()
          require('leap').leap {
            target_windows = { vim.api.nvim_get_current_win() },
          }
        end
      '';
      options.desc = "leap (current window)";
    }

    # Cross-window leap — labels every match across every
    # window in the current tab. Useful when working in splits
    # and you want to land in a different one without
    # `<C-w>w`-cycling there first.
    {
      mode = [ "n" "x" "o" ];
      key = "S";
      action.__raw = ''
        function()
          require('leap').leap {
            target_windows = vim.api.nvim_tabpage_list_wins(0),
          }
        end
      '';
      options.desc = "leap (all windows)";
    }
  ];
}
