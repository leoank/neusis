# VimTeX — the spine of the LaTeX experience: latexmk-driven
# compilation, SyncTeX forward/inverse search with a real PDF viewer,
# rich motions/text-objects (`dse`, `cse`, `]]`, `ie`/`ae`, …), the
# `:VimtexTocOpen` table of contents, and syntax concealment.
#
# Viewer is chosen at build time by platform (VimTeX drives a native
# app, so this cannot be runtime-detected):
#   - Darwin → Skim  (Preferences ▸ Sync must be configured once for
#              inverse search — see docs/kalam/latex-tutorial.md)
#   - Linux  → Zathura (needs xdotool for forward search)
#
# TeX Live is `scheme-medium` (~1.5 GB) — covers the vast majority of
# writing; add packages with `tlmgr`-style overrides or bump the scheme
# if a document needs more. The same package is put on PATH so
# `latexmk` / `latexindent` are available to conform and to `:terminal`.
{ pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  texlive = pkgs.texlive.combined.scheme-medium;
in
{
  plugins.vimtex = {
    enable = true;
    texlivePackage = texlive;

    settings = {
      # Native viewer + SyncTeX. Skim/Zathura both do inverse search;
      # the Skim-side hookup is a one-time GUI step (documented).
      view_method = if isDarwin then "skim" else "zathura";
    }
    // lib.optionalAttrs isDarwin {
      # Reload the PDF and raise Skim on forward search.
      view_skim_sync = 1;
      view_skim_activate = 1;
    }
    // {
      # latexmk is the default compiler; pin an out-of-source build dir
      # so `.aux`/`.fls`/`.synctex.gz` litter stays out of the source
      # tree. `-synctex=1` (added below) is what makes SyncTeX work.
      compiler_method = "latexmk";
      compiler_latexmk = {
        aux_dir = ".build";
        out_dir = ".build";
        options = [
          "-verbose"
          "-file-line-error"
          "-synctex=1"
          "-interaction=nonstopmode"
        ];
      };

      # Don't hijack focus with the quickfix window on every warning
      # (overfull hbox spam). `]d`/`[d`-style navigation still works via
      # `:VimtexErrors` when you want it.
      quickfix_mode = 0;

      # Concealment is driven by `conceallevel=2` (set per-buffer in
      # opts.nix). `m` = conceal math symbols, `g` = Greek, `a` =
      # accents/ligatures, `b` = bold/italic faces.
      syntax_conceal = {
        accents = 1;
        greek = 1;
        math_bounds = 1;
        math_symbols = 1;
        math_fracs = 1;
        math_super_sub = 1;
        styles = 1;
      };
    };
  };

  # Forward-search on Linux/Zathura shells out to xdotool; Skim needs
  # nothing extra. TeX Live goes on PATH for conform + terminal use.
  extraPackages = [ texlive ] ++ lib.optionals (!isDarwin) [ pkgs.xdotool ];

  # which-key: VimTeX's default mappings live under `<localleader>l*`
  # (localleader is `,` — see base/opts.nix). Label the group so the
  # popup is self-describing. Individual `<plug>` maps are provided by
  # VimTeX itself; we only annotate the prefix.
  plugins.which-key.settings.spec = [
    {
      __unkeyed-1 = "<localleader>l";
      group = "vimtex";
    }
  ];
}
