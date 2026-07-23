# LaTeX language servers, layered onto base's `plugins.lsp` (which
# already wires blink.cmp capabilities + the default 0.11 keymaps).
#
#   texlab  — completion for \ref / \cite / package + command names,
#             document symbols, rename across \label/\ref, build-log
#             diagnostics. Build-on-save is left OFF: VimTeX owns
#             compilation, and two builders racing on the same aux dir
#             causes latexmk lock churn.
#   ltex    — grammar, spelling and style checking for the *prose*
#             (LanguageTool under the hood). Noisier than a code LSP by
#             nature; `<leader>ud` (base) toggles diagnostics if it gets
#             in the way. Add project words to a spellfile via its code
#             actions ("Add to dictionary").
{
  plugins.lsp.servers = {
    texlab = {
      enable = true;
      settings.texlab = {
        # VimTeX is the build driver; keep texlab out of the build loop.
        build.onSave = false;
        # Nicer inline diagnostics for chktex-style lint if available.
        chktex = {
          onEdit = false;
          onOpenAndSave = true;
        };
      };
    };

    ltex = {
      enable = true;
      settings.ltex = {
        language = "en-US";
        # Don't lint the machinery, only the words. These are the
        # commands/environments whose *contents* ltex should ignore.
        checkFrequency = "save";
      };
    };
  };
}
