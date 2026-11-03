#!/usr/bin/env bash
# RUN-20261103-g9nmnp: does nixvim emit a portable init.lua for kalam-zero?
# From the repo root: notes/runs/RUN-20261103-g9nmnp/run.sh
# Builds base's keymaps.nix with no plugins twice -- nixvim's defaults, then
# with the four portability knobs -- and checks each init.lua for /nix/store
# paths, vim.loader and runtimepath edits, then loads the portable one in a
# headless nvim with no other config. Writes its outputs next to this script.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(git rev-parse --show-toplevel)
cd "$root"

build() { # $1 = extra nixvim module attrs, $2 = output name
  nix build --impure --no-link --print-out-paths --expr "
    let
      flake = builtins.getFlake (toString ./.);
      sys = builtins.currentSystem;
      pkgs = flake.inputs.nixpkgs.legacyPackages.\${sys};
    in (flake.inputs.nixvim.legacyPackages.\${sys}.makeNixvimWithModule {
      inherit pkgs;
      module = {
        imports = [ ./modules/packages/kalam/_flavors/base/config/keymaps.nix ];
        globals.mapleader = \" \";
        opts = { number = true; grepprg = \"rg --vimgrep\"; };
        $1
      };
    }).config.build.initFile" | tail -1 > "$here/$2.path"
  cp -f "$(cat "$here/$2.path")" "$here/$2.lua"
}

build "" default
build "wrapRc = false; impureRtp = true; luaLoader.enable = null; withPython3 = false; withRuby = false;" portable

for v in default portable; do
  printf '%s: store_paths=%s vim_loader=%s rtp_edits=%s\n' "$v" \
    "$(grep -c /nix/store "$here/$v.lua" || true)" \
    "$(grep -c 'vim.loader' "$here/$v.lua" || true)" \
    "$(grep -c 'runtimepath' "$here/$v.lua" || true)"
done | tee "$here/checks.txt"

nvim=$(nix build --inputs-from . --no-link --print-out-paths nixpkgs#neovim-unwrapped)/bin/nvim
{
  "$nvim" --version | head -1
  "$nvim" --headless --clean -u "$here/portable.lua" \
    +'lua io.stdout:write("leader-space -> " .. vim.fn.maparg("<leader><space>", "n") .. "\n")' \
    +'lua io.stdout:write("errors: " .. vim.v.errmsg .. "\n")' +qa
} 2>&1 | tee "$here/nvim.txt"
rm -f "$here"/*.path
