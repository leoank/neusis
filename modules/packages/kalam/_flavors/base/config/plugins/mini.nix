# mini.nvim owns code-editing QoL. Snacks owns UI/session/picker.
# Don't bind mini's default keymaps explicitly — most of mini is
# invisible-by-default and discovered through which-key when you
# press the trigger (sa, sd, sr for surround; gc for comment; etc.).
# Visible leader bindings live below.
{
  plugins.mini = {
    enable = true;
    modules = {
      # mini.ai removed — treesitter-textobjects owns code-object
      # text objects (`af`/`ac`/`aa`) without contention, vim
      # defaults handle the rest (`a(`, `a"`, `aw`, `ap`, …).
      # See `docs/kalam/base.md` §8a for the why.

      # Auto-pairs.
      pairs = { };

      # gc / gcc — block / line comment toggle.
      comment = { };

      # gs{a,d,r,f,F,h,n} — surround add / delete / replace / find /
      # find-left / highlight / set-n-lines. The default `s*`
      # prefix is moved here so leap.nvim can own `s`/`S` for
      # on-screen jumps. Mnemonic: `gs` → "goto surround mode",
      # parallel to `gc` (comment) and `gS` (splitjoin).
      surround = {
        mappings = {
          add = "gsa";
          delete = "gsd";
          find = "gsf";
          find_left = "gsF";
          highlight = "gsh";
          replace = "gsr";
          update_n_lines = "gsn";
        };
      };

      # Move lines/blocks: Alt+hjkl in normal/visual.
      move = { };

      # Bracket motions: ]d / [d / ]q / [q / etc. across diagnostics,
      # quickfix, buffers, conflicts, …
      bracketed = { };

      # gS — split / join arglists across lines.
      splitjoin = { };

      # Highlight TODO / FIXME / NOTE / etc. and hex colors.
      hipatterns = { };

      # Close buffer without closing the window (used by <leader>bd).
      bufremove = { };

      # Per-cwd session manager. Captures windows, tabs, folds,
      # terminal buffers (see sessionoptions in opts.nix). Auto-save
      # on exit; manual load to keep the dashboard intact on fresh
      # `nvim` invocations.
      sessions = {
        autoread = false;
        autowrite = true;
      };

      # Icon provider used by mini.statusline and friends; snacks
      # consumes this too.
      icons = { };
    };
  };

  keymaps = [
    # mini.bufremove — close buffer without nuking the window.
    {
      mode = "n";
      key = "<leader>bd";
      action.__raw = "function() require('mini.bufremove').delete(0, false) end";
      options.desc = "delete buffer";
    }
    {
      mode = "n";
      key = "<leader>bD";
      action.__raw = "function() require('mini.bufremove').delete(0, true) end";
      options.desc = "delete buffer (force)";
    }

    # Bulk close: all other buffers / all buffers. Uses
    # mini.bufremove so window layout survives. pcall around the
    # delete because modified buffers will refuse and we don't
    # want to abort the whole sweep on the first failure.
    {
      mode = "n";
      key = "<leader>bo";
      action.__raw = ''
        function()
          local cur = vim.api.nvim_get_current_buf()
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if b ~= cur and vim.api.nvim_buf_is_loaded(b) then
              pcall(require('mini.bufremove').delete, b, false)
            end
          end
        end
      '';
      options.desc = "close other buffers";
    }
    {
      mode = "n";
      key = "<leader>ba";
      action.__raw = ''
        function()
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(b) then
              pcall(require('mini.bufremove').delete, b, false)
            end
          end
        end
      '';
      options.desc = "close all buffers";
    }

    # Fast linear navigation: Shift+L / Shift+H. Vim's `L`/`H`
    # defaults (jump to bottom/top of visible window) are seldom
    # used — overriding them for buffer cycling is a common
    # tradeoff. `]b`/`[b` from mini.bracketed still works too.
    {
      mode = "n";
      key = "<S-l>";
      action = "<cmd>bnext<cr>";
      options.desc = "next buffer";
    }
    {
      mode = "n";
      key = "<S-h>";
      action = "<cmd>bprevious<cr>";
      options.desc = "prev buffer";
    }

    # mini.sessions — save/load per-cwd sessions. Session name is
    # the cwd basename, so `~/code/myproject` ↔ session "myproject".
    {
      mode = "n";
      key = "<leader>qs";
      action.__raw = ''
        function()
          require('mini.sessions').write(vim.fs.basename(vim.uv.cwd()))
        end
      '';
      options.desc = "save session";
    }
    {
      mode = "n";
      key = "<leader>ql";
      action.__raw = ''
        function()
          require('mini.sessions').read(vim.fs.basename(vim.uv.cwd()))
        end
      '';
      options.desc = "load session";
    }
    {
      mode = "n";
      key = "<leader>qS";
      action.__raw = "function() require('mini.sessions').select() end";
      options.desc = "select session";
    }
    {
      mode = "n";
      key = "<leader>qd";
      action.__raw = "function() require('mini.sessions').select('delete') end";
      options.desc = "delete session";
    }
  ];
}
