{
  plugins.toggleterm = {
    enable = true;
    settings = {
      size = ''
        function(term)
          if term.direction == "horizontal" then
            return 30
        elseif term.direction == "vertical" then
            return vim.o.columns * 0.4
          end
        end
      '';
      open_mapping = "[[<c-\>]]";
      auto_scroll = false;
      hide_numbers = false;
      shade_terminals = true;
      start_in_insert = false;
      terminal_mappings = true;
      persist_mode = true;
      insert_mappings = true;
      close_on_exit = true;
      shell = "zsh";
      direction = "horizontal"; # 'vertical' | 'horizontal' | 'tab' | 'float'
      float_opts = {
        border = "single"; # 'single' | 'double' | 'shadow' | 'curved' | ... other options supported by win open
        width = 80;
        height = 20;
        winblend = 0;
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<C-\\>";
      action = "<cmd>exe v:count1 . 'ToggleTerm'<cr>";
      options.desc = "Open/Close Terminal";
    }
    {
      mode = "n";
      key = "<leader>tt";
      action = "<cmd>ToggleTermSendCurrentLine<cr>";
      options.desc = "Send current line to terminal";
    }
    {
      mode = "v";
      key = "<leader>tv";
      action = "<cmd>ToggleTermSendVisualLines<cr>";
      options.desc = "Send visual lines to terminal";
    }
    {
      mode = "v";
      key = "<leader>tV";
      action = "<cmd>ToggleTermSendVisualSelection<cr>";
      options.desc = "Send visual selection to terminal";
    }
    {
      mode = "t";
      key = "<C-\\>";
      action = "<cmd>ToggleTerm<cr>";
      options.desc = "Open/Close Terminal";
    }
    {
      mode = "t";
      key = "<esc><esc>";
      action = "<C-\\><C-n>";
      options.desc = "Escape to normal mode";
    }
  ];
}
