{
  plugins = {
    lsp-signature.enable = true;

    lsp = {
      enable = true;
      servers.typos_lsp.enable = true;
      keymaps.lspBuf = {
        "gd" = "definition";
        "gD" = "references";
        "gt" = "type_definition";
        "gi" = "implementation";
        "grn" = "rename";
        "gra" = "code_action";
        "gO" = "document_symbol";
        "K" = "hover";
      };
    };
    lint.enable = true;

  };

}
