{ pkgs, ... }:
{
  plugins = {
    treesitter = {
      enable = true;
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        bash
        json
        lua
        make
        markdown
        nix
        regex
        toml
        xml
        yaml
        python
      ];
      settings = {
        highlight = {
          enable = true;
          disable = [ "latex" ];
          additional_vim_regex_highlighting = [
            "latex"
            "markdown"
          ];
        };
        incremental_selection.enable = true;
        indent.enable = true;
      };
      nixvimInjections = true;
    };
    treesitter-context = {
      enable = false;
      settings = {
        multiline_threshold = 1;
      };
    };
  };
}
