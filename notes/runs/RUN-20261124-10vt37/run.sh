#!/usr/bin/env bash
# RUN-20261124-10vt37: does snacks.image keep a stale conversion of an image edited in
# place, and do deleting its cache files and Snacks.image.image.clear() fix that?
# From the repo root: notes/runs/RUN-20261124-10vt37/run.sh
# kalam (.#kalam) headless with XDG_CACHE_HOME in a temp dir, so the real cache is not
# touched; ImageMagick from the nixpkgs in flake.lock. Writes results.txt beside itself.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${YAJNA_RUN_DIR:-$here}
cd "$(git rev-parse --show-toplevel)"
rev=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
magick=$(nix build --no-link --print-out-paths "github:nixos/nixpkgs/$rev#imagemagick" | head -1)/bin/magick
nvim=$(nix build --no-link --print-out-paths .#kalam | head -1)/bin/nvim

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export XDG_CACHE_HOME=$work/cache PATH="$(dirname "$magick"):$PATH"
# png is used as is; jpg goes through a cached conversion

cat > "$work/probe.lua" <<'LUA'
local src, outfile = _G.arg_src, _G.arg_out
local lines = {}
local function say(s) table.insert(lines, s) end
local function colour(file)
  local r = vim.system({ "magick", file, "-format", "%[pixel:p{32,32}]", "info:" }):wait()
  return vim.trim(r.stdout or "?")
end
local function convert()
  local done = false
  local c = Snacks.image.convert.convert({ src = src, on_done = function() done = true end })
  c:run()
  vim.wait(20000, function() return done end, 50)
  return c
end
say("source: " .. vim.fs.basename(src))
local c1 = convert()
say(("1 red source:   err=%s file=%s colour=%s"):format(tostring(c1:error()), vim.fs.basename(c1.file), colour(c1.file)))
vim.system({ "magick", "-size", "64x64", "xc:blue", src }):wait()  -- same path, new contents
local c2 = convert()
say(("2 blue source:  same file=%s colour=%s  (stale if still red)"):format(tostring(c2.file == c1.file), colour(c2.file)))
for _, f in ipairs(vim.fn.glob(Snacks.image.config.cache .. "/" .. c1.prefix .. ".*", false, true)) do
  os.remove(f)
end
local c3 = convert()
say(("3 cache deleted: colour=%s"):format(colour(c3.file)))
local ok, err = pcall(function()
  local a = Snacks.image.image.new(src)
  local b = Snacks.image.image.new(src)
  Snacks.image.image.clear()
  local c = Snacks.image.image.new(src)
  say(("4 image.new: same before clear=%s, same after clear=%s"):format(tostring(a == b), tostring(a == c)))
end)
if not ok then say("4 image.new failed headless: " .. tostring(err)) end
vim.fn.writefile(lines, outfile)
LUA

: > "$out/results.txt"
for ext in png jpg; do
  src=$work/pic.$ext
  "$magick" -size 64x64 xc:red "$src"
  rm -f "$work/out.txt"
  "$nvim" --headless \
    -c "lua _G.arg_src='$src'; _G.arg_out='$work/out.txt'" \
    -c "luafile $work/probe.lua" -c 'qa!' 2>"$work/err.txt" || true
  { cat "$work/out.txt" 2>/dev/null || { echo "probe failed:"; cat "$work/err.txt"; }; } \
    | sed "s#$work#<tmp>#g" | tee -a "$out/results.txt"
done
