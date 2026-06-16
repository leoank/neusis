{
  plugins = {
    blink-cmp = {
      enable = true;
      settings = {
        completion = {
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 50;
          };
          ghost_text.enabled = true;
        };
        signature.enabled = false;
      };
    };

  };
}
