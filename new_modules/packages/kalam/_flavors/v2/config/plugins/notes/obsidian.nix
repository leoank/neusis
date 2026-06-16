{
  plugins.obsidian = {
    enable = true;
    settings = {
      workspaces = [
        {
          name = "testvault";
          path = "~/workspace/datasets/testvault";
        }
      ];

      legacy_commands = false;

      note_id_func.__raw = "require('obsidian.builtin').title_id";

      notes_subdir = "Notes";
      new_notes_location = "notes_subdir";

      daily_notes = {
        folder = "Daily";
        date_format = "YYYY-MM-DD";
        default_tags = [ "daily" ];
      };

      templates.folder = "Templates";

      attachments.folder = "Attachments";

      completion = {
        blink = true;
        min_chars = 2;
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>nt";
      action = "<cmd>Obsidian template<cr>";
      options = {
        silent = true;
        desc = "Insert template";
      };
    }
    {
      mode = "n";
      key = "<leader>nn";
      action = "<cmd>Obsidian new<cr>";
      options = {
        silent = true;
        desc = "New note";
      };
    }
    {
      mode = "n";
      key = "<leader>ns";
      action = "<cmd>Obsidian search<cr>";
      options = {
        silent = true;
        desc = "Search notes";
      };
    }
    {
      mode = "n";
      key = "<leader>no";
      action = "<cmd>Obsidian quick_switch<cr>";
      options = {
        silent = true;
        desc = "Quick switch note";
      };
    }
    {
      mode = "n";
      key = "<leader>nd";
      action = "<cmd>Obsidian today<cr>";
      options = {
        silent = true;
        desc = "Open daily note";
      };
    }
    {
      mode = "n";
      key = "<leader>nb";
      action = "<cmd>Obsidian backlinks<cr>";
      options = {
        silent = true;
        desc = "Show backlinks";
      };
    }
    {
      mode = "n";
      key = "<leader>nL";
      action = "<cmd>Obsidian follow_link<cr>";
      options = {
        silent = true;
        desc = "Follow link";
      };
    }
  ];
}
