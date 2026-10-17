# yajna.nvim — follow [[ID]] links and @citekeys in a yajna lab notebook,
# find entities, backlinks. Built by the yajna flake (packages.yajna-nvim);
# it maps gf, <C-]>, <localleader>yf and <localleader>yb in markdown
# buffers under a yajna.toml and does nothing elsewhere.
{ pkgs, inputs, ... }:
{
  extraPlugins = [
    inputs.yajna.packages.${pkgs.stdenv.hostPlatform.system}.yajna-nvim
  ];
}
