vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.ruby_host_prog = "/nix/store/h70rzx5lwbwjchdv83h867ahq2z1cax1-neovim-ruby-env/bin/neovim-ruby-host"
vim.g.python3_host_prog = "/nix/store/3jgidmw56qr36hca8jy9vpddqcqpxf91-nvim-host-python3-3.13.17-env/bin/nvim-python3"
-- Ignore the user lua configuration
vim.opt.runtimepath:remove(vim.fn.stdpath("config")) -- ~/.config/nvim
vim.opt.runtimepath:remove(vim.fn.stdpath("config") .. "/after") -- ~/.config/nvim/after

-- Nixvim's internal module table
-- Can be used to share code throughout init.lua
local _M = {}

-- Set up globals {{{
do
    local nixvim_globals = { mapleader = " " }

    for k, v in pairs(nixvim_globals) do
        vim.g[k] = v
    end
end
-- }}}

-- Set up options {{{
do
    local nixvim_options = { grepprg = "rg --vimgrep", number = true }

    for k, v in pairs(nixvim_options) do
        vim.opt[k] = v
    end
end
-- }}}

-- Set up keybinds {{{
do
    local __nixvim_binds = {
        { action = "<cmd>write<cr>", key = "<leader><space>", mode = "n", options = { desc = "save file" } },
        {
            action = "<cmd>nohlsearch<cr><esc>",
            key = "<esc>",
            mode = "n",
            options = { desc = "clear search highlight" },
        },
        {
            action = "<C-\\><C-n>",
            key = "<esc><esc>",
            mode = "t",
            options = { desc = "exit terminal mode", nowait = true },
        },
        { action = '"+y', key = "<leader>y", mode = { "n", "v" }, options = { desc = "yank to system clipboard" } },
        { action = '"+Y', key = "<leader>Y", mode = "n", options = { desc = "yank line to system clipboard" } },
        { action = '"+p', key = "<leader>p", mode = { "n", "v" }, options = { desc = "paste from system clipboard" } },
        { action = '"+P', key = "<leader>P", mode = "n", options = { desc = "paste from system clipboard (before)" } },
    }
    for i, map in ipairs(__nixvim_binds) do
        vim.keymap.set(map.mode, map.key, map.action, map.options)
    end
end
-- }}}
