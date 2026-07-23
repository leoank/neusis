# LuaSnip is already enabled in base (as blink.cmp's snippet backend).
# Here we turn on the two settings that make ejmastnak-style LaTeX
# authoring fast, and load the TeX snippet library.
#
#   enable_autosnippets  — snippets marked `snippetType="autosnippet"`
#                          expand the instant their trigger is typed, no
#                          Tab needed. This is what makes `mk`, `//`,
#                          `;a` etc. feel instantaneous.
#   store_selection_keys — press <Tab> in visual mode to stash the
#                          selection, then type a trigger whose body
#                          uses `get_visual` to wrap it (e.g. select a
#                          word, <Tab>, `mk` → `$word$`).
#
# The snippet files live under `./snippets/tex/*.lua`; LuaSnip's
# from_lua loader treats the subdirectory name as the filetype, so they
# only ever fire in `tex` buffers. Autosnippets coexist with blink —
# blink drives the completion menu, LuaSnip's autocmd handles autoexpand.
{
  plugins.luasnip.settings = {
    enable_autosnippets = true;
    store_selection_keys = "<Tab>";
  };

  plugins.luasnip.fromLua = [
    { paths = [ ./snippets ]; }
  ];
}
