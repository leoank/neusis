{ icons, ... }:
{
  plugins.lualine = {
    enable = true;
    settings = {
      options = {
        always_divide_middle = true;
        globalstatus = true; # have a single statusline at bottom of neovim instead of one for every window
        disabled_filetypes.statusline = [
          "dashboard"
          "alpha"
        ];
        section_separators = {
          left = "";
          right = "";
        };
      };
      extensions = [ "fzf" ];
      sections = {
        lualine_a = [ "mode" ];
        lualine_b = [ "branch" ];
        lualine_y = [
          "filesize"
          "lsp_status"
          "hostname"
          "progress"
        ];
      };
    };
  };
}
