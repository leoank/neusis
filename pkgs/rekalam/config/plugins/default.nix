{
  imports = [
    ./ai/avante.nix
    #./ai/opencode.nix
    ./completion/blink.nix

    ./debug/dap.nix

    ./editor/whichkey.nix
    ./editor/yazi.nix
    ./editor/oil.nix

    ./theme
    ./luasnip
    ./telescope
    #./notes/obsidian.nix

    ./git/gitsigns.nix
    ./git/neogit.nix

    ./lsp/conform.nix
    ./lsp/fidget.nix
    ./lsp/lsp.nix

    ./lang/cpp.nix
    ./lang/css.nix
    ./lang/docker.nix
    ./lang/html.nix
    ./lang/json.nix
    ./lang/lua.nix
    ./lang/markdown.nix
    ./lang/nix.nix
    ./lang/python.nix
    ./lang/shell.nix
    ./lang/typescript.nix
    ./lang/yaml.nix
    ./lang/zig.nix
    ./lang/rust.nix
    ./lang/lean.nix
    #./lang/tex.nix

    ./treesitter/treesitter.nix
    #./treesitter/treesitter-textobjects.nix

    #./ui/alpha.nix
    ./ui/nui.nix
    ./ui/bufferline.nix
    #./ui/general.nix
    ./ui/flash.nix
    ./ui/indent-blankline.nix
    ./ui/lualine.nix
    #./ui/noice.nix
    #./ui/notify.nix
    ./ui/nui.nix
    ./ui/precognition.nix
    ./ui/toggleterm.nix
    ./ui/ufo.nix

    #./util/colorizer.nix
    #./util/debugprint.nix
    ./util/mini.nix
    ./util/nvim-autopairs.nix
    ./util/nvim-surround.nix
    ./util/persistence.nix
    #./util/project-nvim.nix
    ./util/snacks.nix
    ./util/csvview.nix
  ];
}
