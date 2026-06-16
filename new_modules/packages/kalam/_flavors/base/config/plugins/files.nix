# Files / explorer plugins. Complementary, not redundant:
#
#   * oil.nvim   — file system as a buffer. Rename, move, delete by
#                  editing the buffer text and `:w`-ing. Press `<C-p>`
#                  inside the buffer to preview the file under
#                  cursor. Bound to `<leader>o`.
#   * yazi.nvim  — terminal yazi running inside nvim. Floating
#                  popup; navigate, pick a file, return to nvim
#                  with that file open. Bound to `<leader>e`,
#                  replacing snacks.explorer.
{
  plugins = {
    oil = {
      enable = true;
      settings = {
        # Replace netrw so opening a directory in any way lands in
        # oil instead of nvim's built-in dir listing.
        default_file_explorer = true;

        # Show dotfiles + ignored files in the listing.
        view_options = {
          show_hidden = true;
        };

        # Default keymaps already include `<C-p>` for preview and
        # `<C-h>`/`<C-l>` for split-open. Listed here only to make
        # the binding discoverable in this file.
        keymaps = {
          "<C-p>" = "actions.preview";
        };

        # Float-mode dimensions for `:Oil --float`. The default
        # `:Oil` (which we bind below) opens in the current window,
        # which is usually what you want for batch renaming.
        float = {
          padding = 2;
          max_width = 100;
          max_height = 30;
          border = "rounded";
        };
      };
    };

    yazi = {
      enable = true;
      settings = {
        # Open yazi when nvim is invoked on a directory path
        # (`nvim ~/projects`). Keeps the explorer experience
        # consistent regardless of how you launched.
        open_for_directories = true;

        keymaps = {
          show_help = "<f1>";
        };
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>o";
      action = "<cmd>Oil<cr>";
      options.desc = "oil — files as buffer";
    }
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>Yazi<cr>";
      options.desc = "yazi explorer";
    }
  ];
}
