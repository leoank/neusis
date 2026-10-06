{
  colorschemes.catppuccin = {
    enable = true;
    settings = {
      flavour = "macchiato";
      transparent_background = true;
      integrations = {
        blink_cmp = true;
        dap = {
          enabled = true;
          enable_ui = true;
        };
        diffview = true;
        gitsigns = true;
        mini.enabled = true;
        neogit = true;
        octo = true;
        snacks.enabled = true;
        treesitter = true;
        which_key = true;
        native_lsp = {
          enabled = true;
          inlay_hints.background = true;
          virtual_text = {
            errors = [ "italic" ];
            hints = [ "italic" ];
            information = [ "italic" ];
            warnings = [ "italic" ];
          };
          underlines = {
            errors = [ "underline" ];
            hints = [ "underline" ];
            information = [ "underline" ];
            warnings = [ "underline" ];
          };
        };
      };
    };
  };

  # Catppuccin macchiato's diff palette is pastel by design; with
  # transparent_background it washes out further and the eye can't
  # tell DiffChange from context. Override the four standard diff
  # groups + the diffview groups that don't inherit cleanly. Logic:
  #
  #   DiffAdd     — solid, mid-luminance green: "this line is new"
  #   DiffChange  — solid muted blue: "this line differs somewhere"
  #   DiffDelete  — solid red with dim fg: "filler / deleted"
  #   DiffText    — saturated green-on-dark, bold: focal point —
  #                 the bytes that ACTUALLY changed inside a
  #                 DiffChange line. This is where the eye lands;
  #                 it has to pop, not blend.
  #
  # Applied via highlightOverride so it re-fires on ColorScheme
  # changes — survives a `:colorscheme` swap or live reload.
  highlightOverride = {
    # Green tones pulled back: DiffAdd is now a darker forest
    # rather than meadow. DiffText overlays DiffAdd, so it needs
    # a clear bg step-up to be visible — plus a light fg + bold
    # so the *bytes* (the focal point of any diff) stay legible
    # without the neon look the previous iteration had.
    # Red and blue stay as before — they were balanced already.
    DiffAdd    = { bg = "#1f3826";                  };
    DiffChange = { bg = "#2c3e5b";                  };
    DiffDelete = { bg = "#552e2e"; fg = "#8a4a4a"; };
    DiffText   = { bg = "#4d7a2c"; fg = "#f0f0f0"; bold = true; };

    # Diffview-specific groups. Most inherit from Diff* via
    # catppuccin's integration; the two below need explicit bg
    # because catppuccin sets them fg-only.
    DiffviewDiffAddAsDelete = { bg = "#552e2e"; fg = "#8a4a4a"; };
    DiffviewDiffDelete      = { bg = "#552e2e"; fg = "#8a4a4a"; };

    # gitsigns rich view (<leader>uG) — deleted lines surface as
    # virt-text in place of the rows they used to occupy. Without
    # explicit bg these render as red fg on default background,
    # which makes "I deleted this" much harder to spot. Match the
    # DiffDelete palette so the visual story is the same whether
    # you're in gitsigns rich mode or a real diff.
    GitSignsDeleteVirtLn       = { bg = "#552e2e"; fg = "#c87878"; };
    GitSignsDeleteVirtLnInLine = { bg = "#7a3a3a"; fg = "#f0c8c8"; };

    # gitsigns word_diff overlays — the bytes that actually differ
    # WITHIN an added/changed/deleted line. These are the focal
    # point of the rich view and catppuccin's integration sets
    # them fg-only, so without an explicit bg they vanish into
    # the surrounding DiffAdd/DiffChange tint. Each step up is
    # noticeable (~50% brighter than the line bg) with bold +
    # light fg so the changed bytes are *the* thing your eye
    # lands on.
    GitSignsAddInline    = { bg = "#3a6020"; fg = "#f0f0f0"; bold = true; };
    GitSignsChangeInline = { bg = "#3e5a8a"; fg = "#f0f0f0"; bold = true; };
    GitSignsDeleteInline = { bg = "#7a3a3a"; fg = "#f0c8c8"; bold = true; };

    # File-panel signal — counts in the left sidebar. Insertions
    # green toned down to match the subtler diff body.
    DiffviewFilePanelInsertions = { fg = "#6fa84f"; bold = true; };
    DiffviewFilePanelDeletions  = { fg = "#e07070"; bold = true; };

    # The "dim" wash diffview puts on unchanged context lines —
    # nudge up so context is still legible.
    DiffviewDim1 = { fg = "#6a6f80"; };
  };
}
