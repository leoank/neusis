{ pkgs, ... }:
{
  plugins = {
    nix.enable = true;
    hmts.enable = true;
    nix-develop.enable = true;

    conform-nvim.settings = {
      formatters_by_ft = {
        nix = [ "nixfmt-rfc-style" ];
      };

      formatters = {
        nixfmt-rfc-style = {
          command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
        };
      };
    };

    lint = {
      lintersByFt = {
        nix = [ "statix" ];
      };

      linters = {
        statix = {
          cmd = "${pkgs.statix}/bin/statix";
        };
      };
    };

    lsp.servers.nil_ls = {
      enable = true;
      settings = {
        nix.flake.autoArchive = true;
      };
    };
    lsp.servers.nixd.enable = true;
  };

  extraConfigVim = ''
    au BufRead,BufNewFile flake.lock setf json
  '';
}
