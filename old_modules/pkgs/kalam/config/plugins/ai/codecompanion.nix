{ inputs, pkgs, ... }:
{
  plugins.codecompanion = {
    enable = true;
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.vimPlugins.codecompanion-nvim;
    settings = {
      adapters = {
        ollama.__raw = ''
          function()
            return require("codecompanion.adapters").extend("ollama", {
              env = {
                url = "http://karkinos:11434"
              },
              schema = {
                model = {
                  default = "llama3.3:latest";
                },
                num_ctx = {
                  default = 128000;
                }
              }
            })
          end
        '';
      };
      strategies = {
        chat.adapter = "ollama";
        inline.adapter = "ollama";
        agent.adapter = "ollama";
      };
      opts = {
        log_level = "TRACE";
        send_code = true;
        use_default_actions = true;
        use_default_prompts = true;
      };
    };

  };
}
