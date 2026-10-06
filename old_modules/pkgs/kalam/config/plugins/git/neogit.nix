{
  plugins = {
    diffview.enable = true;
    octo.enable = true;

    neogit = {
      enable = true;
      settings = {
        integrations.diffview = true;
      };
    };
  };
  keymaps = [
    {
      mode = "n";
      key = "<leader>gg";
      action = "<cmd>Neogit<CR>";
    }
    {
      mode = "n";
      key = "<leader>goi";
      action = "<cmd>Octo issue list<CR>";
    }
    {
      mode = "n";
      key = "<leader>gop";
      action = "<cmd>Octo pr list<CR>";
    }
    {
      mode = "n";
      key = "<leader>goc";
      action = "<cmd>Octo pr changes<CR>";
    }
    {
      mode = "n";
      key = "<leader>gor";
      action = "<cmd>Octo review<CR>";
    }
  ];
}
