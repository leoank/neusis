-- Project-local nvim config for the neusis flake.
--
-- Loaded by either:
--   * nvim's native exrc (if `exrc = true` is set early enough), OR
--   * kalam's VimEnter autocmd (workaround in
--     base/config/autocmds.nix), which manually re-implements the
--     exrc + trust check.
-- Either way, both end up running this file. Guard prevents
-- double-execution if BOTH fire on the same startup.
--
-- nixd docs:
--   https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md

if vim.g.kalam_neusis_exrc_loaded then return end
vim.g.kalam_neusis_exrc_loaded = true

local flake = vim.uv.cwd()

-- Robust load proof. Every startup that sources this file appends
-- a timestamped line; counting lines per startup tells us whether
-- only one loader fired or both.
pcall(vim.fn.writefile,
  { ("[%s] .nvim.lua sourced; cwd=%s"):format(os.date("%H:%M:%S"), flake) },
  "/tmp/neusis-exrc.log",
  "a"
)

local nixd_settings = {
  nixd = {
    -- `pkgs.<TAB>` / `lib.<TAB>` against the flake's pinned nixpkgs.
    nixpkgs = {
      expr = ('import (builtins.getFlake "%s").inputs.nixpkgs { }'):format(flake),
    },

    -- Module-options completion (`services.<TAB>`,
    -- `home-manager.users.<x>.programs.<TAB>`, etc.). nixd evals
    -- these lazily on first request, so the cost is bounded.
    options = {
      darwin = {
        expr = ('(builtins.getFlake "%s").darwinConfigurations.rogue.options'):format(flake),
      },

      -- Flake-parts options — completion for THIS flake's own
      -- schema (`flake.neusis.*` declared in
      -- `new_modules/lib/neusis-options.nix`).
      --
      -- flake-parts puts everything under a single `flake`
      -- submodule option. nixd needs a plain attrset rooted at
      -- the source-file attribute names, so we descend through
      -- `flake.type.getSubOptions []` and re-wrap as
      -- `{ flake = <subopts>; }` — that way the path you actually
      -- type (`flake.neusis.users.<x>.hmBundles.<y>`) walks
      -- through the tree we returned.
      ["flake-parts"] = {
        expr = ([[
          let
            flake = builtins.getFlake "%s";
            evaluated = flake.inputs.flake-parts.lib.evalFlakeModule
              { inherit (flake) inputs; self = flake; }
              flake.flakeModules.default;
          in
            { flake = evaluated.options.flake.type.getSubOptions []; }
        ]]):format(flake),
      },

      -- home-manager options at root. Lets `K` / `gd` work on HM
      -- paths (`programs.X`, `home.X`, `xdg.X`, etc.) inside ANY
      -- file — including bundle bodies like
      -- `flake.neusis.users.ank.hmBundles.foo = { programs.X = …; }`,
      -- where nixd can't infer the file will be merged into HM at
      -- eval time. The tradeoff: paths that collide with system
      -- namespaces (e.g. `services.X` exists in both) will resolve
      -- against whichever tree nixd checks first.
      ["home-manager"] = {
        expr = ('(builtins.getFlake "%s").darwinConfigurations.rogue.options.home-manager.users.type.getSubOptions []'):format(flake),
      },

      -- Uncomment + adjust when a NixOS host appears:
      -- nixos = {
      --   expr = ('(builtins.getFlake "%s").nixosConfigurations.<host>.options'):format(flake),
      -- },
    },
  },
}

vim.notify(
  ("[neusis] sourced .nvim.lua — pinning nixd to %s"):format(flake),
  vim.log.levels.INFO
)

-- Path 1: native vim.lsp.config (nvim 0.11+). The canonical
-- API per `:help lspconfig-nvim-0.11`. Used directly when nixvim
-- migrates off lspconfig; until then, it's set as a future-proof
-- record that nothing currently reads.
vim.lsp.config("nixd", { settings = nixd_settings })

-- Path 1.5: mutate lspconfig's stored default_config in place.
-- This is what actually injects settings into nixd's INIT params
-- — nixvim drives LSP through nvim-lspconfig, and the next nixd
-- start (forced via LspRestart below) reads from this table.
-- We touch `configs.nixd.default_config.settings` directly instead
-- of calling `lspconfig.nixd.setup()` to avoid the "framework
-- deprecated" warning every launch. lspconfig.configs IS an
-- internal API and could break, but the upstream replacement
-- (vim.lsp.config + ~/.config/nvim/lsp/*.lua) requires nixvim
-- migration first — until then, this is the working compromise.
local has_configs, configs = pcall(require, "lspconfig.configs")
if has_configs and configs.nixd then
  configs.nixd.default_config.settings = vim.tbl_deep_extend("force",
    configs.nixd.default_config.settings or {},
    nixd_settings
  )
end

-- Path 2: patch already-attached + future-attaching nixd clients
-- so settings take effect WITHOUT a server restart. vim.lsp.config
-- only affects future `vim.lsp.start`/`vim.lsp.enable` calls, not
-- a running client.
local function patch_live(client)
  client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, nixd_settings)
  client.settings = client.config.settings
  client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
end

for _, client in ipairs(vim.lsp.get_clients({ name = "nixd" })) do
  patch_live(client)
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("neusis-nixd-settings", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "nixd" then patch_live(client) end
  end,
})

-- Path 3: hardstop. nixd may have cached the empty options tree
-- from its first init (didChangeConfiguration is best-effort).
-- Restart once so the new merged settings take effect at init.
vim.schedule(function()
  pcall(vim.cmd, "LspRestart nixd")
end)
