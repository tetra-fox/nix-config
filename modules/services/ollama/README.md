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

the two models are pulled declaratively via `services.ollama.loadModels`, so a
rebuild fetches them. what's in the stack:

```
qwen3.6:27b   # 17GB, 27B dense, best dense open coder + multimodal. primary
gemma4:26b    # 18GB, 26B MoE / 4B active, multimodal. kept for vision/image work
```

to add another, `ollama pull <name>` by hand or add it to the `loadModels` list.

open the chat UI at <http://localhost:8080>. `WEBUI_AUTH = "False"` skips the login wall (single-user desktop).

## gotchas

- setting `services.open-webui.environment` replaces the module's default env, which includes the three no-telemetry vars; they're re-stated in the module so the analytics stay off
- 24GB vram fits the ~19GB q4 MoE models above with headroom for context; ollama loads all weights into vram even though only a few billion params activate per token. q8 (32GB) and fp16 (61GB) quants spill to system RAM and slow down hard
