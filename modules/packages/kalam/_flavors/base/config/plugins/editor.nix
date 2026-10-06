# Small editor utilities. Each one is too small to deserve its own
# file, but they don't fit cleanly into any of the larger plugin
# groupings (mini, snacks, etc.) either.
#
#   * undotree   — visual undo history. Toggle with `<leader>uu`.
#   * colorizer  — highlight color codes inline (#3b82f6,
#                  rgb(), hsl(), etc.). Auto-attaches; toggle
#                  per-buffer with `:ColorizerToggle`.
{
  plugins = {
    undotree = {
      enable = true;
      settings = {
        # Focus the undotree window when opened (so `j`/`k`
        # navigate the tree without an extra window-jump).
        focus_on_toggle = true;
        # Keep undotree on the right; the source buffer stays
        # in its window on the left.
        window_layout = 3;
      };
    };

    # Colorizer with defaults. Upstream renamed
    # `plugins.nvim-colorizer` → `plugins.colorizer` in recent
    # nixvim. Enabling here gets all common colorizations (hex,
    # rgb, hsl); override via `:ColorizerSetup` if you need to
    # disable `names` (CSS named colors) for a noisy buffer.
    colorizer.enable = true;
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>uu";
      action = "<cmd>UndotreeToggle<cr>";
      options.desc = "undo tree";
    }
    {
      mode = "n";
      key = "<leader>uc";
      action = "<cmd>ColorizerToggle<cr>";
      options.desc = "colorizer";
    }
  ];
}
