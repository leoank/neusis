{ mkPkgs, inputs, ... }:
{
  extraPlugins = [
    (mkPkgs "volt" inputs.volt)
    # (mkPkgs "minty" inputs.minty)
  ];

  plugins.nvim-colorizer = {
    enable = false;
    userDefaultOptions = {
      css = true;
      mode = "virtualtext";
      tailwind = true;
      sass.enable = true;
      virtualtext = "■";
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>uc";
      action = "<cmd>lua require('minty.huefy').open()<cr>";
      options.desc = "Minty Color Picker";
    }
  ];
}
