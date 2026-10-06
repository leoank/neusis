# Buffer-local settings for TeX files. These are prose-editing
# ergonomics that would be wrong globally (concealment, soft wrap,
# spell) so they're scoped to `FileType tex` rather than set in
# base/opts.nix. Equivalent to ejmastnak's `ftplugin/tex.vim`.
{
  autoGroups.kalam_tex = { };

  autoCmd = [
    {
      group = "kalam_tex";
      event = "FileType";
      pattern = [
        "tex"
        "plaintex"
      ];
      callback.__raw = ''
        function()
          -- Render \alpha, \frac, ^, _, etc. as their symbols. VimTeX's
          -- syntax_conceal (vimtex.nix) supplies the rules; this turns
          -- concealment on for the buffer. `concealcursor=""` means the
          -- line under the cursor is *un*concealed so you can edit the
          -- raw source.
          vim.opt_local.conceallevel = 2
          vim.opt_local.concealcursor = ""

          -- Prose wraps at word boundaries and moves by screen line, so
          -- j/k feel natural in long paragraphs. `wrap`/`linebreak` come
          -- from base; the remaps below make cursor motion follow the
          -- visual line rather than the (very long) logical line.
          vim.opt_local.wrap = true
          local map = function(lhs, rhs)
            vim.keymap.set({ "n", "x" }, lhs, rhs, { buffer = true, expr = true, silent = true })
          end
          map("j", "v:count == 0 ? 'gj' : 'j'")
          map("k", "v:count == 0 ? 'gk' : 'k'")

          -- Spell-check the prose. `<leader>us` (base toggle) flips it;
          -- z= suggests, ]s/[s jump between misspellings.
          vim.opt_local.spell = true
          vim.opt_local.spelllang = "en_us"

          -- latexindent (Perl) is slow to start — inside conform's
          -- 500ms format-on-save budget it times out on nearly every
          -- write ("formatter latexindent timeout"). Turn OFF
          -- format-on-save for tex buffers (base's format_on_save
          -- honours vim.b.disable_autoformat); latexindent stays
          -- available on demand via `<leader>cf` (async, untimed).
          vim.b.disable_autoformat = true
        end
      '';
    }
  ];
}
