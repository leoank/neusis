# Plain vim options. No keymaps, no plugin config — those live in
# their own files. Conservative defaults, prefers neovim built-ins.
{
  globals = {
    mapleader = " ";
    # localleader = comma, the conventional VimTeX/LaTeX prefix (`,ll`
    # compile, `,lv` view). nvim's built-in default is `\`; `,` is
    # faster to reach and is what the tex-bearing flavors expect. It
    # only shadows the native `,` (repeat f/t backwards) inside buffers
    # that actually define <localleader> maps — i.e. tex, via VimTeX.
    maplocalleader = ",";
  };

  opts = {
    # Lines
    number = true;
    relativenumber = true;
    cursorline = true;
    scrolloff = 8;
    signcolumn = "yes";
    wrap = false;
    linebreak = true;
    breakindent = true;

    # Indent
    expandtab = true;
    shiftwidth = 2;
    softtabstop = 2;
    tabstop = 2;
    smartindent = true;

    # Search
    ignorecase = true;
    smartcase = true;
    grepprg = "rg --vimgrep";
    grepformat = "%f:%l:%c:%m";

    # Splits
    splitbelow = true;
    splitright = true;

    # Files / undo
    swapfile = false;
    backup = false;
    undofile = true;
    confirm = true;

    # Project-local config. nvim looks for `.nvim.lua` (or
    # `.nvimrc`, `.exrc`) in the cwd at startup. Sourcing is gated
    # by a per-user trust list: `:trust` allows the current file,
    # `:trust deny` blocks it; trust state lives in
    # `$XDG_STATE_HOME/nvim/trust`. Recommended path for per-flake
    # nixd `options.*` config — see this repo's root `.nvim.lua`.
    exrc = true;

    # UI
    termguicolors = true;
    showmode = false; # statusline owns the mode indicator
    cmdheight = 1;
    timeoutlen = 300; # snappier which-key popup
    updatetime = 200;
    mouse = "a";
    virtualedit = "block";
    pumheight = 12;
    completeopt = "menu,menuone,noselect";

    # Folds (treesitter-driven)
    foldenable = true;
    foldlevel = 99;
    foldlevelstart = 99;
    foldmethod = "expr";
    foldexpr = "v:lua.vim.treesitter.foldexpr()";

    # What mini.sessions captures. Skip "options" — saving global
    # options has a knack for breaking colorschemes / plugins on
    # reload. Keep windows/tabs/folds/terminals/buffer-local opts.
    sessionoptions = "buffers,curdir,folds,help,tabpages,terminal,winsize,winpos,localoptions";
  };
}
