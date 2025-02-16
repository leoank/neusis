source ~/.vim/common.vim

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

" yank to clipboard
if has('clipboard')
  set clipboard=unnamed " copy to the system clipboard
endif

" }}}


" Visual Settings -------------------------------------------------------- {{{

" Set a colorscheme $VIMRUNTIME/colors for color schemes shipped with vim
" ~/vim/colors for any of your own
if has('nvim')
  colorscheme vim
endif
"colorscheme elflord
"colorscheme dark-meadow
"colorscheme default
" needed for default vim colorscheme
set notermguicolors

" when search hight pattern match
set incsearch

" when inserting bracket, briefly jump to matching one
set showmatch

" turn syntax highlighting on.
syntax on

" visual mode highlight color
" run "hi" command for all color groups
hi Visual ctermfg=238 ctermbg=117

" highlight 81st column
set colorcolumn=81

" set appropriate color for column highlight
highlight ColorColumn ctermbg=0

" set highlight color
hi Search ctermfg=238 ctermbg=117

" }}}


" MAPPINGS --------------------------------------------------------------- {{{

" Source the vimrc file after saving it
" shortcut to show vimrc file in new tab
nmap <leader>v :tabedit $MYVIMRC<CR>

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

au BufRead,BufNewFile *.zshrc.managed set filetype=zsh
au BufRead,BufNewFile *.bashrc.managed set filetype=bash
au BufRead,BufNewFile *.inputrc.managed set filetype=readline
au BufRead,BufNewFile *.vimrc.managed set filetype=vim
au BufRead,BufNewFile *init.vim.managed set filetype=vim

" }}}

source ~/.vim/plugins.vim
