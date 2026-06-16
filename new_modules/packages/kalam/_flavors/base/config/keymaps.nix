# Core non-plugin keymaps. Deliberately tiny — base prefers neovim
# defaults. Plugin keymaps live alongside their plugin config so
# every binding is one search away from its implementation.
{
  keymaps = [
    # Save with leader-space — leader on its own feels accidental.
    {
      mode = "n";
      key = "<leader><space>";
      action = "<cmd>write<cr>";
      options.desc = "save file";
    }

    # Clear search highlight on Esc (preserves Esc's normal behaviour).
    {
      mode = "n";
      key = "<esc>";
      action = "<cmd>nohlsearch<cr><esc>";
      options.desc = "clear search highlight";
    }

    # Terminal-mode escape. In nvim, a plain `:te` sends `<Esc>`
    # straight to the running program — necessary for apps that
    # consume it (zsh-vi-mode, fzf, less, mc, …). To leave terminal
    # mode you'd normally hit the awkward `<C-\><C-n>`.
    #
    # Snacks's toggle-terminal solves this by binding `<Esc><Esc>`
    # to the escape sequence on the terminal buffer — single Esc
    # still passes through to the shell, double-tap returns to
    # nvim normal mode so window/tab keys (`<C-w>w`, `gt`, …) work.
    # `nowait = true` keeps the second Esc responsive instead of
    # waiting out the timeoutlen.
    #
    # We mirror that here at `mode = "t"` so the binding is global
    # (any `:te` buffer, not just snacks-managed ones). Snacks's
    # buffer-local override still wins inside its own terminals.
    {
      mode = "t";
      key = "<esc><esc>";
      action = "<C-\\><C-n>";
      options = {
        desc = "exit terminal mode";
        nowait = true;
      };
    }

    # System-clipboard yank / paste via the `+` register. These
    # are additive — `y`/`p` keep their default behaviour against
    # the unnamed register so register-juggling tricks still work.
    {
      mode = [ "n" "v" ];
      key = "<leader>y";
      action = "\"+y";
      options.desc = "yank to system clipboard";
    }
    {
      mode = "n";
      key = "<leader>Y";
      action = "\"+Y";
      options.desc = "yank line to system clipboard";
    }
    {
      mode = [ "n" "v" ];
      key = "<leader>p";
      action = "\"+p";
      options.desc = "paste from system clipboard";
    }
    {
      mode = "n";
      key = "<leader>P";
      action = "\"+P";
      options.desc = "paste from system clipboard (before)";
    }
  ];
}
