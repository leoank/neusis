{
  pkgs,
  ...
}:
{

  config = {
    extraPlugins = [
    ];

    extraConfigLua = ''
      --- setup llm-nvim
      -- require("llm").setup({
      --   model = "gpt-oss:latest",
      --   backend = "ollama",
      --   url = "http://karkinos:11434",
      --   context_window = 128000,
      --   accept_keymap = "<C-l>",
      --   dismiss_keymap = "<C-e>",
      --   lsp = {
      --     bin_path = "${pkgs.llm-ls}/bin/llm-ls"
      --   },
      -- })
    '';
  };
}
