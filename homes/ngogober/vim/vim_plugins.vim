" plugin installation, management, and configuration

" `zo` to open a single fold under the cursor
" `zc` to close the fold under the cursor
" `zR` to open all folds
" `zM` to close all folds
" `:help folding` for more info

" vim-plug setup ---------------------------------------------------------- {{{

"  https://github.com/junegunn/vim-plug

" download vim-plug if missing
" https://github.com/junegunn/vim-plug/wiki/tips#automatic-installation
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
endif

" run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

" declare plugins
silent! if plug#begin()

  " manually install with :PlugInstall
  " (but automation above should handle it)
  " update with :PlugUPdate
  " clean unused with :PlugClean

  "Plug '<repo>/<plugin>'
  Plug 'preservim/nerdtree'
  Plug 'itchyny/lightline.vim'
  "Plug 'ctrlpvim/ctrlp.vim'
  "Plug 'junegunn/vim-easy-align'
  "Plug 'tpope/vim-commentary'
  "Plug 'tpope/vim-eunuch'
  "Plug 'tpope/vim-fugitive'
  "Plug 'tpope/vim-repeat'
  Plug 'tpope/vim-surround'
  "Plug 'tpope/vim-unimpaired'
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
  Plug 'neoclide/coc.nvim', {'branch': 'release'}
  Plug 'puremourning/vimspector'
  "Plug 'tpope/vim-sleuth'

  " do :echo v:version to see your version
  " vim and nvim will be different
  "
  " ignore these on older versions of vim
  "if v:version >= 703
    "Plug '<repo>/<plugin>'
  "endif

  call plug#end()
endif

" }}}

" NERDTree ---------------------------------------------------------------- {{{

" https://github.com/preservim/nerdtree

" quick toggle NERDTree
nmap <Leader>n :NERDTreeToggle<CR>
nmap <Leader>g :NERDTreeFind<CR>
" show hidden files by default
let NERDTreeShowHidden=1

" }}}

" light line -------------------------------------------------------------- {{{

"  https://github.com/itchyny/lightline.vim

" fixes status line not showing up
set laststatus=2

" -- insert -- not needed anymore since it's in the satus line
set noshowmode

" colorscheme
let g:lightline = {
      \ 'colorscheme': 'wombat',
      \ }

" }}}

" fzf --------------------------------------------------------------------- {{{
" https://github.com/junegunn/fzf.vim

" :Files [PATH] - $FZF_DEFAULT_COMMAND
" :GFiles [OPTS] - git files (git ls-files)
" :GFiles? = git files (git status)
" :Buffers - open buffers
" :Colors - color schemes
" :Ag [PATTERN] - ag (aka the_silver_search, ack alt); ALT-A to select all, ALT-D to deselect all
" :Rg [PATTERN] - rg (aka ripgrep, grep alt); ALT-A to select all, ALT-D to deselect all
" :RG [PATTERN] - rg; but relaunch ripgrep on every keystroke
" :Lines [QUERY] - lines in loaded buffers
" :Blines [QUERY] - lines in current buffer
" :Marks - marks
" :Jumps - jumps
" :Windows - windows
" :History: - command history
" :History/ - search history
" :Maps - normal mode mappings
" :Helptags - help tags
" :Filetypes - file types
"
" CTRL-T / CTRL-X / CTRL-V to open in new tab, (horizontal) split, vertical split

" overwrite the default Files command - using 'opener' as preview
" https://github.com/junegunn/fzf.vim?tab=readme-ov-file#example-customizing-files-command
command! -bang -nargs=? -complete=dir Files
    \ call fzf#vim#files(<q-args>, {'options': ['--layout=reverse', '--preview', 'opener {}']}, <bang>0)
" ! means fullscreen
" files
nnoremap <Leader>ff :Files<CR>
nnoremap <Leader>fF :Files!<CR>
" files in [PATH]
nnoremap <Leader>fo :Files 
" git ls-files
nnoremap <Leader>fg :GFiles<CR>
" git status
nnoremap <Leader>fs :GFiles?
" open buffers
nnoremap <Leader>fb :Buffers<CR>
" regex [PATTERN]
nnoremap <Leader>fr :Rg 

" }}}

" coc --------------------------------------------------------------------- {{{
" https://github.com/neoclide/coc.nvim

let g:coc_global_extensions = [
      \"coc-json",
      \"coc-docker",
      \"coc-markdownlint",
      \"coc-yaml",
      \"coc-sh",
      \"coc-pyright",
      \"coc-lua",
      \"coc-html",
      \"coc-css",
      \"coc-tsserver",
      \"coc-eslint",
      \"coc-prettier",
      \]

" get definition under cursor
nnoremap ,z :call CocActionAsync('definitionHover')<CR>
" accept completion item
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<C-r>=coc#on_enter()\<CR>"
" GoTo code navigation
nmap <silent><nowait> gd <Plug>(coc-definition)
nmap <silent><nowait> gy <Plug>(coc-type-definition)
nmap <silent><nowait> gi <Plug>(coc-implementation)
nmap <silent><nowait> gr <Plug>(coc-references)
noremap <silent><nowait>gb <C-o>

" Use K to show documentation in preview window
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

" }}}

" vimspector --------------------------------------------------------------------- {{{

" NOTE: in theory vscode-js-debug should in theory subsume vscode-firefox-debug, debugger-for-chrome
" but that seems not to be the case, haven't checked but probably version
" needs updating within vimspector codebase itself
let g:vimspector_install_gadgets = [ 'debugpy', "vscode-js-debug", "debugger-for-chrome" ]

" standard mappings
" (https://github.com/puremourning/vimspector?tab=readme-ov-file#human-mode)
let g:vimspector_enable_mappings = 'HUMAN'

" VimspectorContinue will start if not paused.
nmap dp <Plug>VimspectorContinue
nmap dx <Plug>VimspectorStop
nmap dr <Plug>VimspectorRestart
nmap db <Plug>VimspectorToggleBreakpoint
nmap d\ <Plug>VimspectorStepOver
nmap d] <Plug>VimspectorStepInto
nmap d[ <Plug>VimspectorStepOut
nmap di <Plug>VimspectorBalloonEval
"xmap di <Plug>VimspectorBalloonEval
nmap d, <Plug>VimspectorUpFrame
nmap d. <Plug>VimspectorDownFrame
nmap <Leader>db <Plug>VimspectorBreakpoints
nmap dp <Plug>VimspectorContinue
nmap ,d <Plug>VimspectorLaunch
" }}}

