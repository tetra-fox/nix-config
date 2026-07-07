_: {
  programs.opencode = {
    enable = true;

    settings = {
      # default to the local coder. override per-session in the tui with /models,
      # or swap to a hosted provider (see below).
      model = "ollama/qwen3.6:27b";
      # title/summary generation is cheap; gemma is the lighter of the two, no
      # point spending the dense coder on it
      small_model = "ollama/gemma4:26b";

      # ollama isn't a built-in opencode provider, so define it against the local
      # server. openai-compatible driver, /v1 endpoint from services.ollama.
      provider.ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (local)";
        options.baseURL = "http://127.0.0.1:11434/v1";
        # opencode 1.17 autodiscovers openai-compatible models from /v1/models,
        # so you don't strictly need this map. but its id parser drops names with
        # a second dot (qwen3.6:27b vanishes from the list) unless listed here.
        # so the map is required for qwen3.6, and we list gemma too for a clean
        # picker. remove once the upstream parsing bug is fixed.
        models = {
          # 27B dense, 17GB at q4. best dense open coder (SWE-bench ~77), and
          # multimodal. slower per token than an MoE but the quality is worth it
          "qwen3.6:27b" = {name = "Qwen3.6 27B";};
          # 26B MoE, ~4B active, multimodal. kept for vision/image work
          "gemma4:26b" = {name = "Gemma 4 26B";};
        };
      };
    };
  };
}
