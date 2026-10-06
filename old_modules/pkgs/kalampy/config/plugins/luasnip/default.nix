{ pkgs, ... }:
{
  plugins.luasnip = {
    enable = true;
    settings = {
      enable_autosnippets = true;
      store_selection_keys = "<Tab>";
    };
    fromLua = [
      { }
      { paths = [ ./snippets ]; }
    ];
    fromVscode = [
      {
        lazyLoad = true;
        paths = [
          "${pkgs.vimPlugins.friendly-snippets}"
        ];
      }
    ];
  };
}
