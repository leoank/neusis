-- Greek letters, `;`-prefixed, math-mode only. `;a` → \alpha, `;p` →
-- \pi, `;G` → \Gamma. The `;` prefix is ergonomic (a dead key in
-- ordinary math) and keeps these clear of the letter-pair triggers in
-- math.lua. Table-driven because the bodies are all identical shape.

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node

-- filetype-aware (tex → VimTeX, markdown → treesitter); see luasnip.nix.
local function in_mathzone()
  return _G.kalam_in_mathzone()
end
local mathA = { condition = in_mathzone }

-- trigger key (typed after `;`) → LaTeX command name.
local lower = {
  a = "alpha",
  b = "beta",
  g = "gamma",
  d = "delta",
  e = "epsilon",
  z = "zeta",
  h = "eta",
  q = "theta",
  i = "iota",
  k = "kappa",
  l = "lambda",
  m = "mu",
  n = "nu",
  x = "xi",
  p = "pi",
  r = "rho",
  s = "sigma",
  ["t"] = "tau",
  u = "upsilon",
  f = "phi",
  c = "chi",
  y = "psi",
  w = "omega",
}

-- variant lowercase forms.
local variants = {
  ["ve"] = "varepsilon",
  ["vf"] = "varphi",
  ["vq"] = "vartheta",
  ["vr"] = "varrho",
  ["vs"] = "varsigma",
}

-- capital forms that exist in LaTeX.
local upper = {
  G = "Gamma",
  D = "Delta",
  Q = "Theta",
  L = "Lambda",
  X = "Xi",
  P = "Pi",
  S = "Sigma",
  U = "Upsilon",
  F = "Phi",
  Y = "Psi",
  W = "Omega",
}

local snippets = {}
local function add(map)
  for key, cmd in pairs(map) do
    table.insert(
      snippets,
      s(
        { trig = ";" .. key, snippetType = "autosnippet", wordTrig = false },
        t("\\" .. cmd),
        mathA
      )
    )
  end
end

add(lower)
add(variants)
add(upper)

return snippets
