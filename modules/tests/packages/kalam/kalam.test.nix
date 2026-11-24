# T0: kalam's own commands, read from the package's evaluated nixvim config.
{ ... }:
{
  perSystem =
    { lib, config, ... }:
    let
      cmd = config.packages.kalam.config.userCommands.KalamImageRefresh;
      lua = cmd.command.__raw;
    in
    {
      tests.package-kalam = {
        # an image edited in place shows its new contents (EXP-20261124-10vsty): snacks'
        # conversions and loaded images are dropped, the buffer's images placed again
        test-image-refresh-command = {
          expr = {
            inherit (cmd) desc;
            dropsConversions = lib.hasInfix ''vim.fn.delete(Snacks.image.config.cache, "rf")'' lua;
            dropsLoaded = lib.hasInfix "Snacks.image.image.clear()" lua;
            replaces = lib.hasInfix "Snacks.image.placement.clean(buf)" lua;
            imageBuffer = lib.hasInfix "Snacks.image.buf.attach(buf)" lua;
            documents = lib.hasInfix ''nvim_exec_autocmds("BufWinEnter"'' lua;
            noKeymap = builtins.filter (k: lib.hasInfix "KalamImageRefresh" (toString (k.action.__raw or k.action or ""))) config.packages.kalam.config.keymaps;
          };
          expected = {
            desc = "Re-convert and redraw images whose files changed";
            dropsConversions = true;
            dropsLoaded = true;
            replaces = true;
            imageBuffer = true;
            documents = true;
            noKeymap = [ ];
          };
        };
      };
    };
}
