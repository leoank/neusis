{ pkgs, ... }:
{
  plugins = {
    conform-nvim.settings = {
      formatters_by_ft = {
        json = [ "jq" ];
      };

      formatters = {
        jq = {
          command = "${pkgs.jq}/bin/jq";
        };
      };
    };

    lint = {
      lintersByFt = {
        json = [ "jq" ];
      };

      linters = {
        jq = {
          cmd = "${pkgs.jq}/bin/jq";
          args = [ "." ];
        };
      };
    };

    lsp.servers.jsonls = {
      enable = true;
    };
  };
}
