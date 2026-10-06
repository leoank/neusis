-- Environment scaffolds. Triggered with a leading `:` so they are
-- collision-free autosnippets (no English word starts with `:`) and can
-- fire the instant you type them. Block environments require the
-- trigger at line start (`line_begin`); matrix/cases fire inside math.
--
-- `:beg` is the escape hatch — type any environment name into the first
-- tabstop and it mirrors to the matching \end via `rep`. The named ones
-- (`:eq`, `:ali`, …) are conveniences for the environments you reach for
-- constantly. Triggers are deliberately non-prefixing so each one fires
-- cleanly (`:eq` is not a prefix of `:enum`, etc.).

local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local i = ls.insert_node
local d = ls.dynamic_node
local rep = require("luasnip.extras").rep
local fmta = require("luasnip.extras.fmt").fmta
local line_begin = require("luasnip.extras.expand_conditions").line_begin

local function in_mathzone()
  return vim.fn["vimtex#syntax#in_mathzone"]() == 1
end

local function get_visual(_, parent)
  if #parent.snippet.env.LS_SELECT_RAW > 0 then
    return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
  end
  return sn(nil, i(1))
end

local A = { snippetType = "autosnippet" }
local lineA = { condition = line_begin }
local mathA = { condition = in_mathzone }

return {
  -- Generic: env name mirrors to \end, body wraps any visual selection.
  s(vim.tbl_extend("keep", { trig = ":beg" }, A), fmta([[
    \begin{<>}
        <>
    \end{<>}
  ]], { i(1), d(2, get_visual), rep(1) }), lineA),

  -- Numbered display equation.
  s(vim.tbl_extend("keep", { trig = ":eq" }, A), fmta([[
    \begin{equation}
        <>
    \end{equation}
  ]], { i(1) }), lineA),

  -- Multi-line aligned equations (`&` alignment via `==` in math.lua).
  s(vim.tbl_extend("keep", { trig = ":ali" }, A), fmta([[
    \begin{align}
        <>
    \end{align}
  ]], { i(1) }), lineA),

  -- Itemize / enumerate. `i(0)` leaves the cursor after the first item.
  s(vim.tbl_extend("keep", { trig = ":item" }, A), fmta([[
    \begin{itemize}
        \item <>
    \end{itemize}
  ]], { i(0) }), lineA),

  s(vim.tbl_extend("keep", { trig = ":enum" }, A), fmta([[
    \begin{enumerate}
        \item <>
    \end{enumerate}
  ]], { i(0) }), lineA),

  -- Figure with caption + label.
  s(vim.tbl_extend("keep", { trig = ":fig" }, A), fmta([[
    \begin{figure}[htb!]
        \centering
        \includegraphics[width=<>\linewidth]{<>}
        \caption{<>}
        \label{fig:<>}
    \end{figure}
  ]], { i(1, "0.8"), i(2), i(3), i(4) }), lineA),

  -- Table skeleton.
  s(vim.tbl_extend("keep", { trig = ":tab" }, A), fmta([[
    \begin{table}[htb!]
        \centering
        \begin{tabular}{<>}
            <>
        \end{tabular}
        \caption{<>}
        \label{tab:<>}
    \end{table}
  ]], { i(1, "cc"), i(2), i(3), i(4) }), lineA),

  -- Matrix / cases — used inside a math zone, so no line_begin.
  s(vim.tbl_extend("keep", { trig = ":mat" }, A), fmta([[\begin{pmatrix} <> \end{pmatrix}]], { i(1) }), mathA),
  s(vim.tbl_extend("keep", { trig = ":cas" }, A), fmta([[
    \begin{cases}
        <>
    \end{cases}
  ]], { i(1) }), mathA),
}
