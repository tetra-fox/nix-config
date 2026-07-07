# opencode

agentic coding tui, wired to the local ollama stack (`modules.services.ollama.system`).

```nix
{ modules, ... }: {
  imports = [modules.cli.opencode.home];
}
```

ollama isn't a built-in opencode provider, so this defines one pointing at the
local server's openai-compatible endpoint (`http://127.0.0.1:11434/v1`). default
model is `ollama/qwen3.6:27b`; title generation uses `gemma4:26b`.

## models

opencode only offers models listed in the `provider.ollama.models` map, and the
names must match what you `ollama pull`ed. to add a model: pull it on the host,
then add an entry to the map in `home.nix`.

```sh
ollama pull qwen3.6:27b   # 17GB, 27B dense, best dense open coder + multimodal
ollama pull gemma4:26b    # 18GB, 26B MoE / 4B active, multimodal, kept for vision
```

## using a hosted provider too

opencode knows anthropic/openai/etc. natively; no config needed. run
`opencode auth login`, pick the provider, paste a key, then `/models` in the tui
to switch. handy for offloading the hard steps to a stronger model while cheap
edits stay local. the ollama default here is what you get with no login.

## gotchas

- qwen3.6:27b is dense, so every token activates all 27B params. it's slower to
  generate than an MoE of similar size, but it's the best dense open coder and the
  quality is worth the slower stream for agentic work
- the provider `baseURL` must include `/v1` (openai-compatible path), not the bare
  ollama root
