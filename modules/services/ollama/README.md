# ollama

local llm stack: ollama (inference) + open-webui (chat frontend), both bound to loopback.

```nix
{ modules, ... }: {
  imports = [modules.services.ollama.system];
}
```

built for the rtx 3090 on hara. `package = pkgs.ollama-cuda` for gpu inference; the default package is cpu-only.

- ollama listens on `127.0.0.1:11434` (openai-compatible API at `/v1`)
- open-webui listens on `127.0.0.1:8080`, points at ollama's API

nothing binds a routable address and no firewall port is opened, so the stack stays on the box. an assertion trips if either service is rebound to a non-loopback host without also handling auth and the firewall.

## using it

pull a model once, then it's available in the web UI and the API:

```sh
ollama pull qwen3-coder:30b   # 19GB, 30B MoE / 3.3B active, strongest local coder
ollama pull gemma4:26b        # 18GB, 26B MoE / 4B active, multimodal + reasoning
ollama pull qwen3:8b          # 5GB, small/fast
```

or declare models to pull at activation via `services.ollama.loadModels = [ "qwen3-coder:30b" ];`.

open the chat UI at <http://localhost:8080>. `WEBUI_AUTH = "False"` skips the login wall (single-user desktop).

## gotchas

- setting `services.open-webui.environment` replaces the module's default env, which includes the three no-telemetry vars; they're re-stated in the module so the analytics stay off
- 24GB vram fits the ~19GB q4 MoE models above with headroom for context; ollama loads all weights into vram even though only a few billion params activate per token. q8 (32GB) and fp16 (61GB) quants spill to system RAM and slow down hard
