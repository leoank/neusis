# Markdown rendered in place: render-markdown.nvim draws headings, code
# blocks, tables, lists, checkboxes, callouts and links with treesitter
# in normal mode, and shows the raw text on the cursor line while you
# edit. On by default; `<leader>um` toggles it (a snacks toggle, so
# which-key shows its state under "toggles").
#
# For what a terminal can't draw (mermaid diagrams, KaTeX math),
# markdown-preview.nvim opens a live preview in the browser that
# follows the cursor: `<leader>uM` in a markdown buffer.
{
  plugins.render-markdown = {
    enable = true;
    settings = {
      enabled = true;
      file_types = [ "markdown" ];
      # Checkbox and callout completions from its in-process language
      # server, which blink picks up through its lsp source.
      completions.lsp.enabled = true;
      # LaTeX needs latex2text or utftex, which base doesn't ship.
      latex.enabled = false;
    };
  };

  plugins.markdown-preview = {
    enable = true;
    settings = {
      # Close the browser tab when leaving the buffer; keep the preview
      # from starting on its own.
      auto_close = 1;
      auto_start = 0;
      theme = "dark";
    };
  };
  # Its preview server runs on node; bundle it rather than rely on one
  # being on the host's PATH.
  dependencies.nodejs.enable = true;

  extraConfigLua = ''
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        local ok_snacks, Snacks = pcall(function() return _G.Snacks end)
        if not ok_snacks or not Snacks or not Snacks.toggle then return end
        Snacks.toggle.new({
          id = "render-markdown",
          name = "markdown rendering",
          get = function() return require("render-markdown").get() end,
          set = function(state) require("render-markdown").set(state) end,
        }):map("<leader>um")
      end,
    })

    -- markdown-preview's commands exist only in markdown buffers.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function(ev)
        vim.keymap.set("n", "<leader>uM", "<cmd>MarkdownPreviewToggle<cr>",
          { buffer = ev.buf, desc = "markdown preview (browser)" })
      end,
    })
  '';
}
