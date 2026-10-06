{ pkgs, ... }:
{

  plugins = {
    render-markdown.enable = true;
    clipboard-image = {
      enable = true;
      clipboardPackage = if pkgs.stdenv.isLinux then pkgs.wl-clipboard else pkgs.pngpaste;
    };

    markdown-preview = {
      enable = true;
    };

    lsp.servers = {

      ltex = {
        enable = true;
        filetypes = [
          "markdown"
          "text"
        ];

        settings.completionEnabled = true;

        extraOptions = {
          checkFrequency = "save";
          language = "en-GB";
        };
      };
    };

    lint = {
      lintersByFt.md = [ "markdownlint-cli2" ];
      linters.markdownlint-cli2.cmd = "${pkgs.markdownlint-cli2}/bin/markdownlint-cli2";
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>m";
      action = "<cmd>MarkdownPreviewToggle<cr>";
      options = {
        silent = true;
        desc = "Toggle markdown preview";
      };
    }
  ];
}
