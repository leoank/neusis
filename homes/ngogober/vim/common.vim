" common to vim (.vimrc) neovim (.config/nvim/init.vim), and VS Code's use of
" neovim

" ':set' vs 'set'
" https://vi.stackexchange.com/questions/6778/what-is-the-difference-between-set-and-set-commands-with-or-without-a-leading

" `zo` to open a single fold under the cursor
" `zc` to close the fold under the cursor
" `zR` to open all folds
" `zM` to close all folds
" `:help folding` for more info

" Visual Settings -------------------------------------------------------- {{{

" turn off highlight of search terms by default
set nohls

" }}}


" MAPPINGS --------------------------------------------------------------- {{{

" Mappings code goes here.

map <leader>o o<esc>^DA
map <leader>O O<esc>^DA
map <leader>u o<esc>^Do.<esc>k0Dj$xA
map <leader>U O<esc>^DO.<esc>j0Dk$xA
"
" toggle on/off highlight of search terms
map <leader>\ :set hls!<CR>

" change tab settings
map <leader>t :set expandtab!<CR>:set expandtab?<CR>
"
" increase tab size by 2 spaces
map ]T :set softtabstop+=2 tabstop+=2 shiftwidth+=2<CR>
"
" decrease tab size by 2 spaces
map [T :set softtabstop-=2 tabstop-=2 shiftwidth-=2<CR>

" }}}


" VIMSCRIPT -------------------------------------------------------------- {{{

" }}}

