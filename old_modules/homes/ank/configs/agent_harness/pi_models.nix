{
  providers = {
    lmstudio = {
      baseUrl = "http://localhost:1234/v1";
      api = "openai-completions";
      apiKey = "lm-studio";
      models = [
        {
          id = "google/gemma-4-e4b";
          input = [
            "text"
            "image"
          ];
        }
      ];
    };
  };
}
