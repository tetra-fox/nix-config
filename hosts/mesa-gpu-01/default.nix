{
  config,
  pkgs,
  fleet,
  modules,
  ...
}: let
  whisperPort = 10300;
  # abliterated (refusals removed), text only. stock qwen3.5:9b-q4_K_M stays pulled as a fallback until this proves out
  baseModel = "lukey03/qwen3.5-9b-abliterated";
  textModel = "qwen3.5-abliterated-9b-text";
in {
  imports = [
    modules.profiles.server.system

    modules.hardware.nvidia.system
  ];

  # AI host, running an llm for home assistant natural language thru ollama
  # potentially immich ML as well with the immich-machine-learning docker container
  # and maybe, just maybe rffmpeg for remote transcoding with jellyfin

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # no auth on ollama's api, so it listens east-west and only HAOS gets through the firewall
    host = config.lab.site.internalIp;
    environmentVariables = {
      # keep the model in vram so voice commands don't wait on a reload
      OLLAMA_KEEP_ALIVE = "-1";
      # matches home assistant's context window. a request with a different size reloads the model
      OLLAMA_CONTEXT_LENGTH = "16384";
    };
  };

  # cuda builds for every package that has them, matching what the cuda cache builds
  nixpkgs.config.cudaSupport = true;

  services.wyoming.faster-whisper.servers.ha = {
    enable = true;
    uri = "tcp://${config.lab.site.internalIp}:${toString whisperPort}";
    device = "cuda";
    language = "en";
    sttLibrary = "faster-whisper";
    # qwen leaves ~1.5GB of vram, small-int8 fits in that
    model = "small-int8";
    # home assistant is pointed at the address directly
    zeroconf.enable = false;
  };

  # the vision projector widens llama.cpp's fit target by its size plus 1GiB, which pushes layers
  # onto the cpu next to whisper. assist never sends images, so it uses a copy without it
  systemd.services.ollama-text-model = {
    description = "Create ${textModel} from ${baseModel} without its vision projector";
    wantedBy = ["multi-user.target"];
    after = ["ollama.service"];
    bindsTo = ["ollama.service"];
    path = [pkgs.curl pkgs.jq];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      DynamicUser = true;
    };
    script = ''
      api=http://${config.services.ollama.host}:${toString config.services.ollama.port}/api
      # ollama.service is Type=exec, so it counts as started before the api listens
      until curl -sf "$api/version" >/dev/null; do sleep 1; done
      # pulled here, not via loadModels: the loader is Type=exec and returns before the pull ends.
      # a no-op when the model is already present. assist needs a model with tool calling
      curl -sf "$api/pull" -d '{"model": "${baseModel}", "stream": false}' >/dev/null
      show=$(curl -sf "$api/show" -d '{"model": "${baseModel}"}')
      modelfile=$(jq -r .modelfile <<<"$show")
      # ollama lists the weights first and the projector second
      weights=$(sed -n 's#^FROM .*/blobs/sha256-\([0-9a-f]*\)$#\1#p' <<<"$modelfile" | head -n 1)
      renderer=$(sed -n 's/^RENDERER //p' <<<"$modelfile")
      parser=$(sed -n 's/^PARSER //p' <<<"$modelfile")
      jq -n \
        --arg weights "sha256:$weights" --arg renderer "$renderer" --arg parser "$parser" \
        --argjson show "$show" \
        '{
          model: "${textModel}",
          files: {"model.gguf": $weights},
          template: $show.template,
          renderer: $renderer,
          parser: $parser,
          # one "key value" per line, stop repeats and must be a list. fromjson unquotes strings
          parameters: ($show.parameters | split("\n") | map(select(length > 0) | capture("^(?<k>\\S+)\\s+(?<v>.+)$") | .v |= (fromjson? // .))
            | group_by(.k) | map({(.[0].k): (if .[0].k == "stop" then map(.v) else .[0].v end)}) | add
            # the shipped values are the qwen thinking-mode preset, home assistant runs it with thinking off
            # https://unsloth.ai/docs/models/qwen3.5
            | . + {temperature: 0.7, top_p: 0.8}),
          stream: false
        }' | curl -sf "$api/create" -d @-
    '';
  };

  networking.firewall.extraInputRules = fleet.allow-from [config.lab.appliances.haosIp] [config.services.ollama.port whisperPort];

  lab = {
    site = {
      hostIp = "192.168.10.180";
      internalIp = "10.10.0.180";
    };

    nvidia.exporter.enable = true;
  };

  system.stateVersion = "26.11";
}
