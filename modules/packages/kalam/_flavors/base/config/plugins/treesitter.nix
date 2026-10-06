{
  plugins = {
    treesitter = {
      enable = true;
      nixvimInjections = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
        incremental_selection = {
          enable = true;
          keymaps = {
            init_selection = "<c-space>";
            node_incremental = "<c-space>";
            node_decremental = "<bs>";
            scope_incremental = "<c-s>";
          };
        };
      };
    };

    treesitter-context = {
      enable = true;
      settings = {
        max_lines = 3;
        min_window_height = 20;
      };
    };

    # AST-aware text objects via treesitter. Adds `af`/`if` for
    # function (outer/inner), `ac`/`ic` for class, `aa`/`ia` for
    # parameter. Plus `]f`/`[f` and `]c`/`[c` for next/prev
    # function/class jumps. Strictly more accurate than mini.ai's
    # heuristics for these specific objects (mini.ai stays around
    # for `aa`/`ia` argument matching in non-treesitter contexts).
    treesitter-textobjects = {
      enable = true;
      settings = {
        select = {
          enable = true;
          lookahead = true;
          keymaps = {
            "af" = "@function.outer";
            "if" = "@function.inner";
            "ac" = "@class.outer";
            "ic" = "@class.inner";
            "aa" = "@parameter.outer";
            "ia" = "@parameter.inner";
          };
        };
        move = {
          enable = true;
          set_jumps = true;
          goto_next_start = {
            "]f" = "@function.outer";
            "]c" = "@class.outer";
          };
          goto_next_end = {
            "]F" = "@function.outer";
            "]C" = "@class.outer";
          };
          goto_previous_start = {
            "[f" = "@function.outer";
            "[c" = "@class.outer";
          };
          goto_previous_end = {
            "[F" = "@function.outer";
            "[C" = "@class.outer";
          };
        };
      };
    };
  };
}
