{ avante-nvim, ... }:
{
  plugins.avante = {
    enable = true;
    package = avante-nvim;
    settings = {
      diff = {
        autojump = true;
        debug = false;
        list_opener = "copen";
      };
      highlights = {
        diff = {
          current = "DiffText";
          incoming = "DiffAdd";
        };
      };
      hints = {
        enabled = true;
      };
      mappings = {
        diff = {
          both = "cb";
          next = "]x";
          none = "c0";
          ours = "co";
          prev = "[x";
          theirs = "tc";
        };
      };
      provider = "ollama";
      ollama = {
        endpoint = "karkinos:11434";
        model = "gemma3:27b";
        max_tokens = 100000;
      };

      #auto_suggestion_provider = "";

      web_search_engine = {
        provider = "kagi";
      };

      windows = {
        sidebar_header = {
          align = "center";
          rounded = true;
        };
        width = 30;
        wrap = true;
      };
    };

  };

  plugins.render-markdown = {
    enable = true;
    settings = {
      file_types = [
        "Avante"
      ];
    };
  };
}
