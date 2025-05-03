" common to vim (.vimrc) neovim (.config/nvim/init.vim), and VS Code's use of
" neovim

" ':set' vs 'set'
" https://vi.stackexchange.com/questions/6778/what-is-the-difference-between-set-and-set-commands-with-or-without-a-leading

" `zo` to open a single fold under the cursor
" `zc` to close the fold under the cursor
" `zR` to open all folds
" `zM` to close all folds
" `:help folding` for more info

" General Settings -------------------------------------------------------- {{{

" yank to clipboard
if has('clipboard')
  set clipboard=unnamed " copy to the system clipboard
endif

" }}}


" Visual Settings -------------------------------------------------------- {{{

" turn off highlight of search terms by default
set nohls

" }}}


" MAPPINGS --------------------------------------------------------------- {{{

" Mappings code goes here.

let g:mapleader = " "
let g:maplocalleader = ","

map \o o<esc>^DA
map \O O<esc>^DA
map \u o<esc>^Do.<esc>k0Dj$xA
map \U O<esc>^DO.<esc>j0Dk$xA
"
" toggle on/off highlight of search terms
map \\ :set hls!<CR>

" change tab settings
map \t :set expandtab!<CR>:set expandtab?<CR>
"
" increase tab size by 2 spaces
map ]T :set softtabstop+=2 tabstop+=2 shiftwidth+=2<CR>
"
" decrease tab size by 2 spaces
map [T :set softtabstop-=2 tabstop-=2 shiftwidth-=2<CR>

" }}}


" VIMSCRIPT -------------------------------------------------------------- {{{

" }}}

