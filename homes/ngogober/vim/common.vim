" common to vim (~/.vimrc vi .vimrc) neovim (~/.config/nvim/init.vim via
" nvim_init.vim)
source ~/superhome/config/vim/base.vim

" ':set' vs 'set'
" https://vi.stackexchange.com/questions/6778/what-is-the-difference-between-set-and-set-commands-with-or-without-a-leading

" `zo` to open a single fold under the cursor
" `zc` to close the fold under the cursor
" `zR` to open all folds
" `zM` to close all folds
" `:help folding` for more info

" General Settings -------------------------------------------------------- {{{

" mouse mode on
set mouse=a

set encoding=utf-8

" Disable compatibility with vi which can cause unexpected issues.
set nocompatible

" Enable type file detection. Vim will be able to try to detect the type of file in use.
filetype on

" Enable plugins and load plugin for the detected file type.
filetype plugin on

" Load an indent file for the detected file type.
filetype indent on
" automatically indent on new line to match above line indent
set autoindent

" tab settings
" tab size 2, fine tune to 2, normal mode tab insert at 2, use spaces
set tabstop=2 softtabstop=2 shiftwidth=2 expandtab

" Do not wrap lines. Allow long lines to extend as far as the line goes.
set nowrap

" Turn on hybrid line numbering
" https://jeffkreeftmeijer.com/vim-number/
set number relativenumber
"
" hybrid numbers in Normal mode only
" define an autonumber group named 'numbertoggle'
augroup numbertoggle
  " clear existing autocommands in group
  autocmd!
  " enable relative numbers in Normal mode
  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
  " disable relative numbers in insert mode & when losing focus (e.g.
  " switching windows)
  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
augroup END

" fix backspace not working problem
set backspace=2

" }}}

" Visual Settings -------------------------------------------------------- {{{

" Set a colorscheme $VIMRUNTIME/colors for color schemes shipped with vim
" $HOME/.vim/colors for any of your own
" ln -s $SUPERHOME/config/vim/colors $HOME/.vim/colors
" run "hi" command for all color groups
if has('nvim')
  "colorscheme vim

  set termguicolors

  "highlight Normal guifg=NONE guibg=NONE

  "highlight SignColumn ctermbg=0
  "highlight clear SignColumn

  " visual mode highlight color
  " run "hi" command for all color groups
  "highlight Visual guifg=#444444 guibg=#87d7ff

  " set appropriate color for column highlight
  "highlight ColorColumn guibg=#000000

  " set highlight color
  "highlight Search guifg=#444444 guibg=#87d7ff
else
  set background=dark
  "colorscheme elflord
  "colorscheme dark-meadow
  "colorscheme default
  "colorscheme solarized

  " needed for default vim colorscheme
  set notermguicolors

  " clears the gutter to prevent it from being gray for whatever reason
  highlight clear SignColumn

  " column highlight to none
  highlight ColorColumn ctermbg=0

  " sets visual mode and search to cyan, for some unknown reason
  highlight Visual ctermfg=238 ctermbg=117
  highlight Search ctermfg=238 ctermbg=117
endif

" when search hight pattern match
set incsearch

" when inserting bracket, briefly jump to matching one
set showmatch

" turn syntax highlighting on.
syntax on

" vim gutter - always on
" auto is annoying with coc, which uses the gutter often
set signcolumn=yes

" highlight 161st column
set colorcolumn=161


" }}}

" MAPPINGS --------------------------------------------------------------- {{{

" Move focus to the left window
nmap <C-h> <C-w><C-h>
" Move focus to the right window
nmap <C-l> <C-w><C-l>
" Move focus to the lower window
nmap <C-j> <C-w><C-j>
" Move focus to the upper window
nmap <C-k> <C-w><C-k>

" copy paste to clipboard
" copy from visual mode
vmap <C-c> "*y
" paste when in insert mode
imap <C-v> <ESC>"*p

" show tabs, spaces and trailing spaces
" hellowo	r	l			d
"
"map ]t :set list<CR>:set listchars=space:.,tab:▸·,trail:·<CR>
map ]t :set list<CR>:set listchars=space:.,trail:+,tab:>-<CR>
"
" unshow tabs and trailing spaces
map [t :set nolist<CR>


" }}}

" VIMSCRIPT -------------------------------------------------------------- {{{

" This will enable code folding.
" Use the marker method of folding.
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker
augroup END

" }}}

" MISC ------------------------------------------------------------------- {{{

" Misc stuff.

" set syntax for various custom filetypes
" https://stackoverflow.com/questions/11666170/persistent-set-syntax-for-a-given-filetype
" when opening a file in vim, can do :setlocal syntax? to see what filetype it
" detected

" no longer needed
" au BufRead,BufNewFile *.zshrcmanaged set filetype=zsh

"
" }}}

