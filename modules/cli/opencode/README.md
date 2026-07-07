# opencode

agentic coding tui, wired to the local ollama stack (`modules.services.ollama.system`).

```nix
{ modules, ... }: {
  imports = [modules.cli.opencode.home];
}
```

ollama isn't a built-in opencode provider, so this defines one pointing at the
local server's openai-compatible endpoint (`http://127.0.0.1:11434/v1`). default
model is `ollama/qwen3-coder:30b`; title generation uses `qwen3:8b`.

## models

opencode only offers models listed in the `provider.ollama.models` map, and the
names must match what you `ollama pull`ed. to add a model: pull it on the host,
then add an entry to the map in `home.nix`.

```sh
ollama pull qwen3-coder:30b   # 19GB, 30B MoE / 3.3B active, strongest local coder
ollama pull gemma4:26b        # 18GB, 26B MoE / 4B active, multimodal + reasoning
ollama pull qwen3:8b          # 5GB, small/fast, used for title generation
```

## using a hosted provider too

opencode knows anthropic/openai/etc. natively; no config needed. run
`opencode auth login`, pick the provider, paste a key, then `/models` in the tui
to switch. handy for offloading the hard steps to a stronger model while cheap
edits stay local. the ollama default here is what you get with no login.

## gotchas

- agentic coding leans on tool-calling and long context. qwen3-coder:30b is the
  strongest local pick that fits (MoE, so fast despite the size); the 8B connects
  fine but is weaker at multi-step tool use
- the provider `baseURL` must include `/v1` (openai-compatible path), not the bare
  ollama root
