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
      basedpyright = {
        enable = true;
        extraOptions.settings = {
          # Using Ruff's import organizer
          basedpyright.disableOrganizeImports = true;
          basedpython.analysis = {
            # Ignore all files for analysis to exclusively use Ruff for linting
            ignore.__raw = ''{ '*' }'';
          };
        };
      };

      ruff = {
        enable = true;
      };
    };
  };
}
