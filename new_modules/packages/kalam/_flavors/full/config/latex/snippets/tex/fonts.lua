-- Font / face commands.
--
-- Text faces (\textbf, \emph, …) are *regular* snippets: they surface
-- in the blink completion menu when you type the trigger, and you
-- accept to expand. They are intentionally NOT autosnippets — trigger
-- strings like "bf"/"emp" are too close to real words to auto-fire
-- safely in prose.
--
-- Math faces (\mathbb, \mathcal, …) ARE autosnippets, gated to math
-- zones where the letter combinations don't collide with prose.
--
-- All of them wrap a <Tab>-stashed visual selection via `get_visual`.

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local i = ls.insert_node
local d = ls.dynamic_node
local fmta = require("luasnip.extras.fmt").fmta

local function in_mathzone()
  return vim.fn["vimtex#syntax#in_mathzone"]() == 1
end

local function get_visual(_, parent)
  if #parent.snippet.env.LS_SELECT_RAW > 0 then
    return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
  end
  return sn(nil, i(1))
end

-- Text faces: { trigger, command }. Regular (menu-driven) snippets.
local text_faces = {
  { "bf", "textbf" },
  { "ita", "textit" },
  { "emp", "emph" },
  { "mono", "texttt" },
  { "tsc", "textsc" },
}

-- Math faces: { trigger, command }. Autosnippets, math-zone only.
local math_faces = {
  { "mbb", "mathbb" },
  { "mcal", "mathcal" },
  { "mbf", "mathbf" },
  { "mrm", "mathrm" },
  { "mfr", "mathfrak" },
}

local snippets = {}

for _, e in ipairs(text_faces) do
  table.insert(
    snippets,
    s({ trig = e[1] }, fmta("\\" .. e[2] .. "{<>}", { d(1, get_visual) }))
  )
end

for _, e in ipairs(math_faces) do
  table.insert(
    snippets,
    s(
      { trig = e[1], snippetType = "autosnippet" },
      fmta("\\" .. e[2] .. "{<>}", { d(1, get_visual) }),
      { condition = in_mathzone }
    )
  )
end

return snippets
