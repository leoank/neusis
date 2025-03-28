" do `source ~/superhome/config/vim/nvim_init.vim` in ~/.config/nvim/init.vim

if exists('g:vscode')
  source ~/superhome/config/vim/base.vim
else
  " ordinary Neovim stuff

  set runtimepath^=~/.vim runtimepath+=~/.vim/after
  let &packpath = &runtimepath
  source ~/superhome/config/vim/common.vim
end

