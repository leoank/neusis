{ pkgs, ... }:
{
  plugins = {

    web-devicons.enable = true;
    telescope = {
      enable = true;
      extensions = {
        fzf-native.enable = true;
        undo.enable = true;
        ui-select = {
          settings = {
            specific_opts = {
              codeactions = true;
            };
          };
        };
      };

      settings.defaults = {
        prompt_prefix = "   ";
        color_devicons = true;
        set_env.COLORTERM = "truecolor";

        # trim leading whitespace from grep
        vimgrep_arguments = [
          "${pkgs.ripgrep}/bin/rg"
          "--color=never"
          "--no-heading"
          "--with-filename"
          "--line-number"
          "--column"
          "--smart-case"
          "--trim"
        ];
      };
      keymaps = {
        "<leader>ff" = {
          action = "find_files hidden=true";
          options.desc = "Find project files";
        };
        "<leader>fw" = {
          action = "live_grep";
          options.desc = "Grep (root dir)";
        };
        "<leader>fb" = {
          action = "buffers";
          options.desc = "Select open buffers";
        };
        "<leader>:" = {
          action = "command_history";
          options.desc = "Command History";
        };
        "<leader>fr" = {
          action = "oldfiles";
          options.desc = "Recent";
        };
        "<c-p>" = {
          mode = [
            "n"
            "i"
          ];
          action = "registers";
          options.desc = "Select register to paste";
        };
        "<leader>fc" = {
          action = "commands";
          options.desc = "Commands";
        };
        "<leader>fd" = {
          action = "diagnostics bufnr=0";
          options.desc = "Workspace diagnostics";
        };
        "<leader>fh" = {
          action = "help_tags";
          options.desc = "Help pages";
        };
        "<leader>fk" = {
          action = "keymaps";
          options.desc = "Key maps";
        };
        "<leader>fM" = {
          action = "man_pages";
          options.desc = "Man pages";
        };
        "<leader>fm" = {
          action = "marks";
          options.desc = "Jump to Mark";
        };
        "<leader>fo" = {
          action = "vim_options";
          options.desc = "Options";
        };
        "<leader>fC" = {
          action = "colorscheme";
          options.desc = "Colorscheme preview";
        };
      };
    };
  };
}
