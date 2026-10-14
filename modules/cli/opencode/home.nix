_: {
  programs.opencode = {
    enable = true;

    settings = {
      model = "ollama/qwen3.6:27b";
      # title/summary generation, the lighter model is enough
      small_model = "ollama/gemma4:26b";

      provider.ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (local)";
        options.baseURL = "http://127.0.0.1:11434/v1";
        # opencode 1.17's /v1/models discovery drops ids with a second dot (qwen3.6:27b)
        # TODO: drop once upstream parses them
        models = {
          "qwen3.6:27b" = {name = "Qwen3.6 27B";};
          "gemma4:26b" = {name = "Gemma 4 26B";};
        };
      };
    };
  };
}
