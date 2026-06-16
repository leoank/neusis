{
  plugins = {
    mini = {
      enable = true;
      modules = {
        ai = {
          n_lines = 100;
          search_method = "cover_or_next";
        };
        comment = {
          options = {
            customCommentString = ''
              <cmd>lua require("ts_context_commentstring.internal").calculate_commentstring() or vim.bo.commentstring<cr>
            '';
          };
        };
        # Highlight word under cursor
        cursorword = {
          delay = 0;
        };

        # Show indent lines
        indentscope = {
          symbol = "│";
          draw.delay = 0;
        };
      };
    };

    ts-context-commentstring.enable = true;
  };
}
