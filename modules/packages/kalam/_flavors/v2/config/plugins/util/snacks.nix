{
  config,
  lib,
  pkgs,
  ...
}:
{
  plugins = {
    snacks = {
      enable = true;

      settings = {
        bigfile = {
          enabled = true;
          size = 1024 * 1024; # 1MB
        };
        quickfile.enabled = true;
        zen.enabled = true;
        animate.enabled = true;
        input.enabled = true;
        dashboard = {
          enabled = false;
          preset.header = [
            ''
              .-.__      \\ .-.  ___  __
              |_|  '--.-.-(   \\/\\;;\\_\\.-._______.-.
              (-)___     \\ \\ .-\\ \\;;\\(   \\       \\ \\
               Y    '---._\\_((Q)) \\;;\\\\ .-\\     __(_)
               I           __'-' / .--.((Q))---'    \\
               I     ___.-:    \\|  |   \\'-'_          \\
               A  .-'      \\ .-.\\   \\   \\ \\ '--.__     '\\
               |  |____.----((Q))\\   \\__|--\\_      \\     '
                  ( )        '-'  \\_  :  \\-' '--.___\\
                   Y                \\  \\  \\       \\(_)
                   I                 \\  \\  \\         \\
                   I                  \\  \\  \\          \\
                   A                   \\  \\  \\          '\\
                   |              ank   \\  \\__|           '
                                         \\_:.  \\
                                           \\ \\  \\
                                            \\ \\  \\
                                             \\_\\_|
            ''
          ];
          sections = [

            { section = "header"; }
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
            { section = "startup"; }
          ];
        };
      };
    };
  };

  # keymaps = [
  #   {
  #     mode = "n";
  #     key = "<leader>gl";
  #     action = "<cmd>lua Snacks.lazygit()<CR>";
  #     options = {
  #       desc = "Open lazygit";
  #     };
  #   }
  # ];
}
