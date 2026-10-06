-- Auto-sized delimiters, `lr`-prefixed, math-mode only. `lr(` →
-- `\left( \right)`, and the closing delimiter is emitted for you so the
-- pair always balances. Wraps a visual selection when one was stashed
-- with <Tab>. (VimTeX can also toggle/change delimiters after the fact
-- with `dse`/`cse` and `<localleader>ts` for \left\right sizing.)

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local i = ls.insert_node
local d = ls.dynamic_node
local fmta = require("luasnip.extras.fmt").fmta

-- filetype-aware (tex → VimTeX, markdown → treesitter); see luasnip.nix.
local function in_mathzone()
  return _G.kalam_in_mathzone()
end
local mathA = { condition = in_mathzone }

local function get_visual(_, parent)
  if #parent.snippet.env.LS_SELECT_RAW > 0 then
    return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
  end
  return sn(nil, i(1))
end

-- trigger → { open, close } delimiter commands. Quoted (not long-
-- bracket) strings so a trailing `]` in `\right]` doesn't collide with
-- Lua's `]]` string terminator.
local pairs_ = {
  ["lr("] = { "\\left( ", " \\right)" },
  ["lr["] = { "\\left[ ", " \\right]" },
  ["lr{"] = { "\\left\\{ ", " \\right\\}" },
  ["lr|"] = { "\\left| ", " \\right|" },
  ["lra"] = { "\\left\\langle ", " \\right\\rangle" },
}

local snippets = {}
for trig, delim in pairs(pairs_) do
  table.insert(
    snippets,
    s(
      { trig = trig, snippetType = "autosnippet", wordTrig = false },
      fmta(delim[1] .. "<>" .. delim[2], { d(1, get_visual) }),
      mathA
    )
  )
end

return snippets
