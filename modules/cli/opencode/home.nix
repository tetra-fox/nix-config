_: {
  programs.opencode = {
    enable = true;

    settings = {
      # default to the local ollama coder model. override per-session in the tui
      # with /models, or swap to a hosted provider (see below).
      model = "ollama/qwen3-coder:30b";
      # title/summary generation is cheap, don't spend the big model on it
      small_model = "ollama/qwen3:8b";

      # ollama isn't a built-in opencode provider, so define it against the local
      # server. openai-compatible driver, /v1 endpoint from services.ollama.
      provider.ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (local)";
        options.baseURL = "http://127.0.0.1:11434/v1";
        # models must be listed here for opencode to offer them; the names have to
        # match what `ollama pull` fetched. add more as you pull them.
        models = {
          # 30B MoE, ~3.3B active per token, 19GB at q4. strongest local coder
          "qwen3-coder:30b" = {name = "Qwen3 Coder 30B";};
          # 26B MoE, ~4B active, multimodal + reasoning. good non-coding sibling
          "gemma4:26b" = {name = "Gemma 4 26B";};
          "qwen3:8b" = {name = "Qwen3 8B";};
        };
      };
    };
  };
}
