-- Math snippets, modelled on ejmastnak's vim-latex snippet reference.
--
-- Two families:
--   * math-mode *entry* snippets (mk, dm) — gated to `in_text` so they
--     only fire in prose, and they open a math zone.
--   * in-math snippets (//, sr, sum, …) — gated to `in_mathzone` so the
--     short triggers never clobber ordinary words in prose.
--
-- Everything here is an autosnippet: it expands the moment the trigger
-- is typed. Triggers are chosen to "roll" on the home row and to avoid
-- common English letter pairs where possible; the regex-guarded ones
-- (`mk`) additionally refuse to fire mid-word.

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local fmta = require("luasnip.extras.fmt").fmta
local line_begin = require("luasnip.extras.expand_conditions").line_begin

-- Context helpers — filetype-aware, defined once in luasnip.nix's
-- extraConfigLua (VimTeX for tex, treesitter for markdown). Called at
-- expand time, so the globals are always set by then.
local function in_mathzone()
  return _G.kalam_in_mathzone()
end
local function in_text()
  return _G.kalam_in_text()
end

-- Re-insert the character a regex trigger consumed (capture group 1).
local function cap1(_, snip)
  return snip.captures[1]
end

-- Wrap the text visually selected before expansion (stashed by <Tab>,
-- see luasnip.nix), or fall back to an empty insert node.
local function get_visual(_, parent)
  if #parent.snippet.env.LS_SELECT_RAW > 0 then
    return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
  end
  return sn(nil, i(1))
end

local A = { snippetType = "autosnippet" }
-- Concatenating variant: `wordTrig = false` so the trigger fires even
-- when it directly follows a letter/digit. Postfix snippets (^2, _{},
-- …) MUST attach to the preceding token with no space — with the
-- default `wordTrig = true`, `xsr` wouldn't expand at all and you'd be
-- forced to type `x sr`, leaving a stray space (`x ^2`).
local AW = { snippetType = "autosnippet", wordTrig = false }
local mathA = { condition = in_mathzone }

return {
  ---------------------------------------------------------------------
  -- Entering math (text-mode only)
  ---------------------------------------------------------------------
  -- Inline math: `mk` → `$ $`, refusing to fire inside a word so
  -- "remark", "make" etc. are safe. The captured leading char is
  -- re-emitted, then the cursor lands between the dollars.
  s(
    vim.tbl_extend("keep", { trig = "([^%a])mk", regTrig = true, wordTrig = false }, A),
    fmta("<>$<>$", { f(cap1), d(1, get_visual) }),
    { condition = in_text }
  ),
  -- Same but at the very start of a line (no leading char to capture).
  s(
    vim.tbl_extend("keep", { trig = "^mk", regTrig = true, wordTrig = false }, A),
    fmta("$<>$", { d(1, get_visual) }),
    { condition = in_text }
  ),
  -- Display math on its own line. Delimiters are filetype-aware:
  -- `\[ \]` in tex, `$$ $$` in markdown — markdown's treesitter only
  -- recognises `$$…$$` (not `\[…\]`) as a math zone, so using `$$`
  -- keeps the inner math snippets firing there.
  s(vim.tbl_extend("keep", { trig = "dm" }, A), fmta([[
    <>
      <>
    <>
  ]], {
    f(function()
      return vim.bo.filetype == "markdown" and "$$" or "\\["
    end),
    i(1),
    f(function()
      return vim.bo.filetype == "markdown" and "$$" or "\\]"
    end),
  }), { condition = line_begin }),

  ---------------------------------------------------------------------
  -- Fractions, powers, roots (math-mode only)
  ---------------------------------------------------------------------
  -- Postfix / fraction: attach directly to the preceding token, so
  -- `wordTrig = false` (AW). Type `xsr` → `x^2`, `a__i` → `a_{i}`.
  s(vim.tbl_extend("keep", { trig = "//" }, AW), fmta([[\frac{<>}{<>}]], { d(1, get_visual), i(2) }), mathA),
  s(vim.tbl_extend("keep", { trig = "sr" }, AW), t("^2"), mathA), -- square
  s(vim.tbl_extend("keep", { trig = "cb" }, AW), t("^3"), mathA), -- cube
  s(vim.tbl_extend("keep", { trig = "td" }, AW), fmta([[^{<>}]], { i(1) }), mathA), -- superscript
  s(vim.tbl_extend("keep", { trig = "__" }, AW), fmta([[_{<>}]], { i(1) }), mathA), -- subscript
  s(vim.tbl_extend("keep", { trig = "sq" }, A), fmta([[\sqrt{<>}]], { d(1, get_visual) }), mathA),
  s(vim.tbl_extend("keep", { trig = "ee" }, A), fmta([[e^{<>}]], { i(1) }), mathA), -- exponential

  ---------------------------------------------------------------------
  -- Big operators
  ---------------------------------------------------------------------
  s(vim.tbl_extend("keep", { trig = "sum" }, A), fmta([[\sum_{<>}^{<>} ]], { i(1), i(2) }), mathA),
  s(vim.tbl_extend("keep", { trig = "prod" }, A), fmta([[\prod_{<>}^{<>} ]], { i(1), i(2) }), mathA),
  s(vim.tbl_extend("keep", { trig = "lim" }, A), fmta([[\lim_{<> \to <>} ]], { i(1, "n"), i(2, "\\infty") }), mathA),
  s(vim.tbl_extend("keep", { trig = "dint" }, A), fmta([[\int_{<>}^{<>} <> \, d<>]], { i(1), i(2), i(3), i(4) }), mathA),
  s(vim.tbl_extend("keep", { trig = "ooo" }, A), t([[\infty]]), mathA),

  ---------------------------------------------------------------------
  -- Relations & operators
  ---------------------------------------------------------------------
  s(vim.tbl_extend("keep", { trig = "!=" }, A), t([[\neq]]), mathA),
  s(vim.tbl_extend("keep", { trig = "<=" }, A), t([[\leq]]), mathA),
  s(vim.tbl_extend("keep", { trig = ">=" }, A), t([[\geq]]), mathA),
  s(vim.tbl_extend("keep", { trig = "~~" }, A), t([[\sim]]), mathA),
  s(vim.tbl_extend("keep", { trig = "~=" }, A), t([[\approx]]), mathA),
  s(vim.tbl_extend("keep", { trig = "==" }, A), t([[&=]]), mathA), -- alignment point
  s(vim.tbl_extend("keep", { trig = "xx" }, A), t([[\times]]), mathA),
  s(vim.tbl_extend("keep", { trig = "**" }, A), t([[\cdot]]), mathA),
  s(vim.tbl_extend("keep", { trig = "->" }, A), t([[\to]]), mathA),
  s(vim.tbl_extend("keep", { trig = "!>" }, A), t([[\mapsto]]), mathA),
  s(vim.tbl_extend("keep", { trig = "=>" }, A), t([[\implies]]), mathA),
  s(vim.tbl_extend("keep", { trig = "=<" }, A), t([[\impliedby]]), mathA),
  s(vim.tbl_extend("keep", { trig = "iff" }, A), t([[\iff]]), mathA),
  s(vim.tbl_extend("keep", { trig = "fa" }, A), t([[\forall]]), mathA),
  s(vim.tbl_extend("keep", { trig = "tee" }, A), t([[\exists]]), mathA),
  s(vim.tbl_extend("keep", { trig = "..." }, A), t([[\dots]]), mathA),

  ---------------------------------------------------------------------
  -- Text inside math, and postfix accents
  ---------------------------------------------------------------------
  s(vim.tbl_extend("keep", { trig = "tt" }, A), fmta([[\text{<>}]], { d(1, get_visual) }), mathA),
  -- Postfix accents: type the letter, then the trigger. `xbarr` →
  -- `\bar{x}`. Doubled last letter so common words (…bar/…hat/…vec)
  -- don't accidentally trip them. Only single letters, only in math.
  s(
    vim.tbl_extend("keep", { trig = "([%a])barr", regTrig = true, wordTrig = false }, A),
    fmta([[\bar{<>}]], { f(cap1) }),
    mathA
  ),
  s(
    vim.tbl_extend("keep", { trig = "([%a])hatt", regTrig = true, wordTrig = false }, A),
    fmta([[\hat{<>}]], { f(cap1) }),
    mathA
  ),
  s(
    vim.tbl_extend("keep", { trig = "([%a])vecc", regTrig = true, wordTrig = false }, A),
    fmta([[\vec{<>}]], { f(cap1) }),
    mathA
  ),
}
