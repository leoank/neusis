{ pkgs, ... }:
{
  plugins = {
    dap.extensions.dap-python.enable = true;
    jupytext.enable = true;

    conform-nvim.settings = {
      formatters_by_ft.python = [
        "ruff_format"
        "ruff_organize_imports"
      ];
    };

    lint = {
      lintersByFt.python = [ "mypy" ];
      linters.mypy = {
        cmd = "${pkgs.mypy}/bin/mypy";
        args = [ "--ignore-missing-imports" ];
      };
    };

    lsp.servers = {
      pyright = {
        enable = true;
      };

      ruff = {
        enable = true;
      };
    };
  };
}
