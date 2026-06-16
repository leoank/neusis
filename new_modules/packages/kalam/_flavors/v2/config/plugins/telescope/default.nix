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
        #zoxide.enable = true;
        manix.enable = true;
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
        # General
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
        "<leader>ft" = {
          action = "treesitter";
          options.desc = "List function names, variables, from Treesitter";
        };
        "<leader>:" = {
          action = "command_history";
          options.desc = "Command History";
        };
        "<leader>fR" = {
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
        "<leader>fn" = {
          action = "manix";
          options.desc = "Nix search";
        };
        # "<leader>fz" = {
        #   action = "zoxide list";
        #   options.desc = "Zoxide";
        # };

        # LSP related
        "<leader>flr" = {
          action = "lsp_references";
          options.desc = "Lists LSP references for word under the cursor";
        };
        "<leader>fli" = {
          action = "lsp_incoming_calls";
          options.desc = "Lists LSP incoming calls for word under the cursor";
        };
        "<leader>flo" = {
          action = "lsp_outgoing_calls";
          options.desc = "Lists LSP outgoing calls for word under the cursor";
        };
        "<leader>fld" = {
          action = "lsp_document_symbols";
          options.desc = "Lists LSP document symbols in current buffer";
        };
        "<leader>flw" = {
          action = "lsp_workspace_symbols";
          options.desc = "Lists LSP workspace symbols in current workspace";
        };
        "<leader>fls" = {
          action = "lsp_dynamic_workspace_symbols";
          options.desc = "Dynamically lists LSP for all workspace symbols";
        };
        "<leader>flm" = {
          action = "lsp_implementation";
          options.desc = "Goto the implementation of the word under the cursor";
        };
        "<leader>fle" = {
          action = "lsp_definition";
          options.desc = "Goto the definition of the word under the cursor";
        };
        "<leader>flt" = {
          action = "lsp_type_definitions";
          options.desc = "Goto the type definition of the word under the cursor";
        };

        # Git related
        "<leader>fgc" = {
          action = "git_commits";
          options.desc = "List git commits with diff preview";
        };
        "<leader>fgr" = {
          action = "git_bcommits_range";
          options.desc = "List buffer's git commits in a range of lines";
        };
        "<leader>fgb" = {
          action = "git_branches";
          options.desc = "List all branches with log preview";
        };
        "<leader>fgs" = {
          action = "git_status";
          options.desc = "List current changes per file with diff preview";
        };
        "<leader>fgt" = {
          action = "git_stash";
          options.desc = "List stash items in current repository";
        };
      };
    };
  };
}
