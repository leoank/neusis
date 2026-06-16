# Format-on-save + manual format via conform.nvim. Dispatches per
# filetype to external formatter binaries (added to extraPackages
# below). LSP formatting is the fallback when no formatter is
# registered for a filetype.
{ pkgs, ... }:
{
  plugins.conform-nvim = {
    enable = true;
    settings = {
      formatters_by_ft = {
        nix = [ "nixfmt" ];
        python = [ "ruff_organize_imports" "ruff_format" ];
        # Flavors layer more in by extending this attrset.
      };

      # Function form lets us gate format-on-save behind a global
      # flag that `<leader>uf` flips. Disabled by default; the
      # absence of `vim.g.disable_autoformat` means "format on save".
      format_on_save.__raw = ''
        function(bufnr)
          if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return
          end
          return { timeout_ms = 500, lsp_format = "fallback" }
        end
      '';

      # Surface "no formatter wired up for this filetype" instead
      # of silently doing nothing. Drop if it gets noisy.
      notify_no_formatters = true;
    };
  };

  # Formatter binaries. The LSPs themselves come from nixvim's
  # plugins.lsp.servers wiring; formatters don't, so they get
  # added explicitly.
  extraPackages = with pkgs; [
    nixfmt-rfc-style
    ruff
  ];

  keymaps = [
    {
      mode = [ "n" "v" ];
      key = "<leader>cf";
      action.__raw = ''
        function()
          require('conform').format({ async = true, lsp_format = "fallback" })
        end
      '';
      options.desc = "format buffer";
    }
    {
      mode = "n";
      key = "<leader>uf";
      action.__raw = ''
        function()
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify(
            "format on save: " .. (vim.g.disable_autoformat and "off" or "on"),
            vim.log.levels.INFO
          )
        end
      '';
      options.desc = "format on save";
    }
  ];
}
