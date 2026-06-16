{ pkgs, ... }:
{
  plugins = {
    zig.enable = true;

    lsp.servers = {
      zls = {
        enable = true;
      };

    };
  };
}
