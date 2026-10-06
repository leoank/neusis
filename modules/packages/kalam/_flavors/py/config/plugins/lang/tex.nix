{ specObj, pkgs, ... }:
{
  plugins = {
    lsp.servers.texlab.enable = true;
    vimtex = {
      enable = true;
      texlivePackage = pkgs.texlive.combined.scheme-full;
      settings = {
        view_method = "sioyek";
      };
    };
  };

  extraConfigLuaPre = ''
    vim.g.vimtex_compiler_latexmk = {
      aux_dir = ".buildtex" -- you can set here whatever name you desire
    }
  '';

  globals = {
    maplocalleader = ","; # Set the local leader to ","
  };

  plugins.which-key.settings.spec = [
    (specObj [
      "<leader>t"
      ""
      "tex"
    ])
    (specObj [
      "<leader>tl"
      ""
      "vimtex"
    ])
  ];
}
