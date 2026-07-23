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

  # Shared, filetype-aware math-context detection + reuse of the tex
  # snippet set in markdown.
  #
  # The from_lua snippet files aren't on Lua's package.path, so the
  # detector is exposed as globals they call from their `condition`s
  # (evaluated at expand time, so definition order is irrelevant):
  #   - tex/plaintex → VimTeX's syntax engine (vimtex#syntax#in_mathzone)
  #   - markdown     → treesitter: cursor inside an `inline_formula`
  #                    ($...$) or `displayed_equation` ($$...$$) node
  #
  # `filetype_extend` makes markdown buffers load every tex snippet. The
  # math ones fire only inside markdown math (via the detector), `mk`/`dm`
  # enter math from prose, and the text-face snippets self-gate to tex
  # (see fonts.lua) since markdown has its own bold/italic syntax.
  extraConfigLua = ''
    function _G.kalam_is_tex()
      local ft = vim.bo.filetype
      return ft == "tex" or ft == "plaintex"
    end

    function _G.kalam_in_mathzone()
      if vim.bo.filetype == "markdown" then
        -- get_node() reads the current (possibly stale) tree; force an
        -- incremental parse so the block-level `displayed_equation`
        -- ($$…$$) node is up to date after the just-typed character.
        local ok, parser = pcall(vim.treesitter.get_parser, 0)
        if not ok or not parser then
          return false
        end
        pcall(function()
          parser:parse(true)
        end)
        local node = vim.treesitter.get_node({ ignore_injections = false })
        while node do
          local t = node:type()
          if t == "inline_formula" or t == "displayed_equation" or t == "latex_block" then
            return true
          end
          node = node:parent()
        end
        return false
      end
      return vim.fn["vimtex#syntax#in_mathzone"]() == 1
    end

    function _G.kalam_in_text()
      return not _G.kalam_in_mathzone()
    end

    require("luasnip").filetype_extend("markdown", { "tex" })
  '';
}
