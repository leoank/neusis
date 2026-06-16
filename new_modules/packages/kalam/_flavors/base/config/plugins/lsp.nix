# Generic LSP scaffolding only — no language servers declared here.
# Language flavors (py, v2, …) add `servers.<lang>.enable = true`.
#
# Keeps neovim 0.11+ default keymaps (gd, K, grn, gra, gri, grr,
# ]d/[d). We annotate with `desc` so which-key shows them labelled.
{
  plugins.lsp = {
    enable = true;
    inlayHints = true;

    # Extend the default LSP `capabilities` with blink.cmp's
    # completion capabilities. Without this, language servers
    # advertise basic completion only and blink can't drive
    # snippet / resolve / additional-text-edits features. This
    # block is a snippet that nixvim splices into the
    # capabilities-construction lua — `capabilities` is the local
    # variable in scope.
    capabilities = ''
      capabilities = require('blink.cmp').get_lsp_capabilities(capabilities)
    '';

    servers = {
      # Nix — `nixd` over `nil_ls`/`rnix-lsp` for flake-aware
      # completion and real module-options resolution (it shells
      # out to the actual Nix evaluator).
      #
      # Base only configures the project-AGNOSTIC bits here:
      # `nixpkgs.expr` for `pkgs.<TAB>` completion, plus the
      # formatter command. Module-options completion
      # (`services.<TAB>` etc.) needs to know which flake +
      # which host to evaluate against — that's project-specific,
      # so it lives in a `.nvim.lua` exrc at the project root.
      # See https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md
      nixd = {
        enable = true;
        settings = {
          nixpkgs.expr = "import <nixpkgs> { }";
          formatting.command = [ "nixfmt" ];
        };
      };

      # Python — pyright for type checking + completion. ruff
      # handles linting/format (see formatting.nix).
      pyright.enable = true;
    };

    keymaps = {
      diagnostic = {
        "[d" = { action = "goto_prev"; desc = "prev diagnostic"; };
        "]d" = { action = "goto_next"; desc = "next diagnostic"; };
        "<leader>cd" = { action = "open_float"; desc = "line diagnostics"; };
      };

      # nvim 0.11 defaults — re-stated here only for which-key descs.
      lspBuf = {
        "gd" = { action = "definition"; desc = "go to definition"; };
        "gD" = { action = "declaration"; desc = "go to declaration"; };
        "gi" = { action = "implementation"; desc = "go to implementation"; };
        "gy" = { action = "type_definition"; desc = "go to type definition"; };
        "gr" = { action = "references"; desc = "references"; };
        "K"  = { action = "hover"; desc = "hover docs"; };
        "<leader>cr" = { action = "rename"; desc = "rename symbol"; };
        "<leader>ca" = { action = "code_action"; desc = "code action"; };
      };
    };
  };

  # Inline LSP progress / status near the cursor.
  plugins.fidget = {
    enable = true;
    settings = {
      progress.display.progress_icon.pattern = "dots";
      notification.window.winblend = 0;
    };
  };
}
