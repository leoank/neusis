{ ... }:
{
  plugins.oil = {
    enable = true;
    settings = {
      columns = [
        "icon"
        "size"
        "permissions"
      ];
      deleteToTrash = true;
      skip_confirm_for_simple_edits = true;
      useDefaultKeymaps = false;
      view_options = {
        show_hidden = true;
      };
      preview = {
        border = "rounded";
        win_options = {
          winblend = 0;
        };
      };
      keymaps = {
        "g?" = "actions.show_help";
        "<CR>" = "actions.select";
        "<C-\\>" = "actions.select_vsplit";
        "<C-enter>" = "actions.select_split"; # this is used to navigate left
        "<C-t>" = "actions.select_tab";
        "<C-p>" = "actions.preview";
        "<C-c>" = "actions.close";
        "<C-r>" = "actions.refresh";
        "-" = "actions.parent";
        "_" = "actions.open_cwd";
        "`" = "actions.cd";
        "~" = "actions.tcd";
        "gs" = "actions.change_sort";
        "gx" = "actions.open_external";
        "g." = "actions.toggle_hidden";
        "q" = "actions.close";
      };
    };
  };
  keymaps = [
    {
      mode = "n";
      key = "<leader>o";
      action = ":Oil<CR>";
      options = {
        desc = "Oil";
        silent = true;
      };
    }
  ];

}
