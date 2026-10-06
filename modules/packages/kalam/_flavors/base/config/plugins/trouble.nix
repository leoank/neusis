# trouble.nvim — pretty panel for diagnostics, references,
# quickfix, loclist, and symbols. Replaces poking at the raw
# quickfix window for most LSP-discovered things.
#
# Bound under `<leader>x*` (the diagnostics/list group).
# Different from `<leader>sd` (snacks.picker diagnostics) —
# trouble is a persistent split, picker is a one-shot fuzzy find.
{
  plugins.trouble = {
    enable = true;
    settings = {
      focus = true;
      auto_close = true;
      modes = {
        # Right-side split for symbols (acts like a sticky outline).
        symbols.win.position = "right";
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>xx";
      action = "<cmd>Trouble diagnostics toggle<cr>";
      options.desc = "diagnostics (workspace)";
    }
    {
      mode = "n";
      key = "<leader>xX";
      action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
      options.desc = "diagnostics (buffer)";
    }
    {
      mode = "n";
      key = "<leader>xs";
      action = "<cmd>Trouble symbols toggle focus=false<cr>";
      options.desc = "symbols outline";
    }
    {
      mode = "n";
      key = "<leader>xl";
      action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>";
      options.desc = "lsp definitions / references";
    }
    {
      mode = "n";
      key = "<leader>xL";
      action = "<cmd>Trouble loclist toggle<cr>";
      options.desc = "location list";
    }
    {
      mode = "n";
      key = "<leader>xQ";
      action = "<cmd>Trouble qflist toggle<cr>";
      options.desc = "quickfix list";
    }
  ];
}
