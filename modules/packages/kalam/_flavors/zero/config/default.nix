# kalam-zero — kalam for machines without Nix (ADR-0016).
#
# Base's options and plain keymaps, verbatim, plus `zero.lua`: built-in
# fallbacks for the shortcuts base gets from plugins, and the
# conveniences that matter over ssh (OSC 52 copy, grep without rg, a
# plugin-free statusline). Its plugins, oil.nvim and a few mini.nvim
# modules, travel inlined in the released file (ADR-0017, ADR-0018); no
# external packages. Everything that needs a newer Neovim than 0.8 is
# behind a version check in Lua, and mini only runs on 0.10+.
#
# `packages.kalam-zero` is this config wrapped by nixvim, for trying it
# locally; `packages.kalam-zero-init` is the same config rendered as a
# standalone init.lua (see ../../kalam.nix).
{ lib, pkgs, ... }:
{
  enableMan = false;
  withPython3 = false;
  withRuby = false;

  imports = [
    ../../base/config/opts.nix
    ../../base/config/keymaps.nix
  ];

  opts = {
    # base folds with treesitter (`vim.treesitter.foldexpr`, nvim 0.10+)
    foldmethod = lib.mkForce "indent";
    foldexpr = lib.mkForce "0";
    # On 0.8 `exrc` sources a project's .nvim.lua with no trust prompt;
    # on a machine you ssh into, that's someone else's code.
    exrc = lib.mkForce false;
    # Set in zero.lua only when the terminal advertises truecolor.
    termguicolors = lib.mkForce false;
    # base's 300 ms is tuned for which-key's popup; without it, three-key
    # leader sequences need more time.
    timeoutlen = lib.mkForce 800;
  };

  # The wrapped package loads these the normal way; kalam-zero-init
  # inlines the same packages instead (../../kalam.nix).
  extraPlugins = [
    pkgs.vimPlugins.oil-nvim
    pkgs.vimPlugins.mini-nvim
  ];

  extraConfigLua = builtins.readFile ./zero.lua;
}
