{ pkgs, lib, ... }:
{
  plugins = {
    conform-nvim.settings = {
      formatters_by_ft.html = [
        "prettierd"
        "prettier"
      ];

      formatters = {
        prettierd.command = "${pkgs.prettierd}/bin/prettierd";
        prettier.command = "${pkgs.nodePackages.prettier}/bin/prettier";
      };
    };

    lsp.servers = {
      html.enable = true;
      emmet_ls.enable = true;
    };
  };
}
