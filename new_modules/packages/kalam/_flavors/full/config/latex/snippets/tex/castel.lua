-- Math snippets adapted from Gilles Castel's latex-snippets
-- (https://github.com/gillescastel/latex-snippets) and his blog post
-- "How I'm able to take notes in mathematics lectures using LaTeX and
-- Vim" (https://castel.dev/post/lecture-notes-1/), rewritten as our
-- style of math-zone-gated LuaSnip autosnippets.
--
-- Only snippets we did NOT already have live here (fractions, powers,
-- greek, relations, delimiters, etc. are in the sibling files). Every
-- snippet is gated to math via the shared `_G.kalam_in_mathzone`
-- (VimTeX in tex, treesitter in markdown), so they work in `.md` math
-- too.
--
-- wordTrig convention:
--   - postfix / concatenating (attach to the preceding token) and
--     symbol pairs → wordTrig = false
--   - word-like operators you type at a boundary → default (true)
--   - function names → regex guarded (see below)

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local fmta = require("luasnip.extras.fmt").fmta

local function in_mathzone()
  return _G.kalam_in_mathzone()
end
local mathA = { condition = in_mathzone }

local function cap1(_, snip)
  return snip.captures[1]
end
local function cap2(_, snip)
  return snip.captures[2]
end

local function get_visual(_, parent)
  if #parent.snippet.env.LS_SELECT_RAW > 0 then
    return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
  end
  return sn(nil, i(1))
end

local M = {}
local function add(snippet)
  table.insert(M, snippet)
end

---------------------------------------------------------------------
-- Auto-subscript (Castel's signature). Type a letter then a digit.
---------------------------------------------------------------------
-- `x1` → `x_1`
add(s(
  { trig = "([%a])(%d)", regTrig = true, wordTrig = false, snippetType = "autosnippet" },
  fmta("<>_<>", { f(cap1), f(cap2) }),
  mathA
))
-- `x_12` → `x_{12}` (second digit promotes the subscript into braces)
add(s(
  { trig = "([%a])_(%d%d)", regTrig = true, wordTrig = false, snippetType = "autosnippet" },
  fmta("<>_{<>}", { f(cap1), f(cap2) }),
  mathA
))

---------------------------------------------------------------------
-- Auto-backslash for function/operator names: `sin` → `\sin`, etc.
-- Regex-guarded: fires only when preceded by a non-letter, non-`\`
-- char (so `arcsin` doesn't trip `sin`, and a hand-typed `\sin`
-- isn't doubled). The captured char is re-emitted.
---------------------------------------------------------------------
local functions = {
  "arcsin", "arccos", "arctan", -- inverse trig first (longest) — order is cosmetic; regex guard handles overlap
  "sinh", "cosh", "tanh",
  "sin", "cos", "tan", "cot", "sec", "csc",
  "ln", "log", "exp",
  "det", "dim", "gcd", "min", "max",
}
for _, fn in ipairs(functions) do
  add(s(
    { trig = "([^%a\\])" .. fn, regTrig = true, wordTrig = false, snippetType = "autosnippet" },
    { f(cap1), t("\\" .. fn) },
    mathA
  ))
end

---------------------------------------------------------------------
-- Number systems: `RR` → `\mathbb{R}`, etc.
---------------------------------------------------------------------
for _, L in ipairs({ "R", "N", "Z", "Q", "C" }) do
  add(s(
    { trig = L .. L, snippetType = "autosnippet", wordTrig = false },
    t("\\mathbb{" .. L .. "}"),
    mathA
  ))
end

---------------------------------------------------------------------
-- Set theory / logic symbols.
---------------------------------------------------------------------
-- { trigger, replacement, wordTrig }
local symbols = {
  { "inn", "\\in", false },
  { "notin", "\\notin", false },
  { "cap", "\\cap", true },
  { "cup", "\\cup", true },
  { "sub", "\\subset", true },
  { "OO", "\\emptyset", false },
  { "nabl", "\\nabla", true },
}
for _, e in ipairs(symbols) do
  local cfg = { trig = e[1], snippetType = "autosnippet" }
  if e[3] == false then
    cfg.wordTrig = false
  end
  add(s(cfg, t(e[2]), mathA))
end

---------------------------------------------------------------------
-- Inverse / postfix.
---------------------------------------------------------------------
-- `Ainvs` → `A^{-1}` (attaches to the preceding token)
add(s(
  { trig = "invs", snippetType = "autosnippet", wordTrig = false },
  t("^{-1}"),
  mathA
))

---------------------------------------------------------------------
-- Wrapping delimiters / decorations — wrap a <Tab> visual selection
-- or leave the cursor inside.
---------------------------------------------------------------------
-- { trigger, open, close }
local wraps = {
  { "norm", "\\lVert ", " \\rVert" },
  { "abs", "\\lvert ", " \\rvert" },
  { "ceil", "\\lceil ", " \\rceil" },
  { "floor", "\\lfloor ", " \\rfloor" },
  { "set", "\\{ ", " \\}" },
  { "conj", "\\overline{", "}" },
}
for _, e in ipairs(wraps) do
  add(s(
    { trig = e[1], snippetType = "autosnippet", wordTrig = false },
    fmta(e[2] .. "<>" .. e[3], { d(1, get_visual) }),
    mathA
  ))
end

---------------------------------------------------------------------
-- Calculus.
---------------------------------------------------------------------
-- Partial derivative `\frac{\partial <>}{\partial <>}`
add(s(
  { trig = "part", snippetType = "autosnippet" },
  fmta([[\frac{\partial <>}{\partial <>}]], { i(1), i(2) }),
  mathA
))

return M
