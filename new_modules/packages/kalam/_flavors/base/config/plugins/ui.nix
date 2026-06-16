# Visible chrome: statusline + bufferline + icon provider.
# Status column, indent guides, notifications, picker, dashboard,
# zen — those live in snacks.nix. Mode rendering, mini text-edits —
# those live in mini.nix.
{
  plugins = {
    web-devicons.enable = true;

    lualine = {
      enable = true;
      settings = {
        options = {
          theme = "catppuccin";
          globalstatus = true;
          section_separators = { left = ""; right = ""; };
          component_separators = { left = ""; right = ""; };
        };
        sections = {
          lualine_a = [ "mode" ];
          lualine_b = [ "branch" ];
          lualine_c = [
            {
              __unkeyed-1 = "diagnostics";
              symbols = {
                error = " ";
                warn  = " ";
                info  = " ";
                hint  = " ";
              };
            }
            "filename"
          ];
          lualine_x = [ "diff" "filesize" "filetype" ];
          lualine_y = [ "progress" ];
          lualine_z = [ "location" ];
        };
      };
    };

    bufferline = {
      enable = true;
      settings.options = {
        diagnostics = "nvim_lsp";
        always_show_bufferline = false;
        show_buffer_close_icons = false;
        show_close_icon = false;
        offsets = [
          { filetype = "snacks_layout_box"; text = "Explorer"; }
        ];
      };
    };
  };
}
