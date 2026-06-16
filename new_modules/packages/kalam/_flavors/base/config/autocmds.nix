{
  autoGroups = {
    kalam_yank = { };
    kalam_cursor = { };
    kalam_trim = { };
    kalam_exrc = { };
  };

  autoCmd = [
    # Brief highlight on yank — visual confirmation that the yank happened.
    {
      group = "kalam_yank";
      event = "TextYankPost";
      pattern = "*";
      callback.__raw = ''
        function()
          vim.hl.on_yank({ timeout = 150 })
        end
      '';
    }

    # Restore cursor position when reopening a file.
    # Skip for commit messages so you land at the top.
    {
      group = "kalam_cursor";
      event = "BufReadPost";
      pattern = "*";
      callback.__raw = ''
        function()
          local row, col = unpack(vim.api.nvim_buf_get_mark(0, '"'))
          local lcount = vim.api.nvim_buf_line_count(0)
          if row > 0 and row <= lcount
            and vim.bo.filetype ~= "commit"
            and vim.bo.filetype ~= "gitrebase"
          then
            pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
          end
        end
      '';
    }

    # Manual exrc loader — workaround for cases where nvim's
    # builtin exrc mechanism doesn't fire (option-timing edge
    # cases, certain wrappers). Runs after init.lua, picks up
    # `.nvim.lua` from cwd, honours the standard `vim.secure.read`
    # trust check. Drop this once nvim's native exrc reliably
    # loads in this environment.
    {
      group = "kalam_exrc";
      event = "VimEnter";
      pattern = "*";
      callback.__raw = ''
        function()
          local path = vim.fn.getcwd() .. "/.nvim.lua"
          if vim.fn.filereadable(path) ~= 1 then return end
          local ok, content = pcall(vim.secure.read, path)
          if not ok or content == nil then return end
          local chunk, err = loadstring(content, "@" .. path)
          if chunk then
            chunk()
          else
            vim.notify("[kalam-exrc] " .. tostring(err), vim.log.levels.ERROR)
          end
        end
      '';
    }

    # Trim trailing whitespace on save.
    {
      group = "kalam_trim";
      event = "BufWritePre";
      pattern = "*";
      callback.__raw = ''
        function()
          if vim.bo.binary or vim.bo.filetype == "diff" then return end
          local view = vim.fn.winsaveview()
          vim.cmd([[keeppatterns %s/\s\+$//e]])
          vim.fn.winrestview(view)
        end
      '';
    }
  ];
}
