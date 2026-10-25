{
  config,
  pkgs,
  fleet,
  modules,
  ...
}: {
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
    };
    # home assistant's assist needs tool calling. the 6.6GB q4 leaves little of the 2080 super's 8GB
    # for anything else on the gpu
    loadModels = ["qwen3.5:9b-q4_K_M"];
  };

  networking.firewall.extraInputRules = fleet.allow-from [config.lab.appliances.haosIp] [config.services.ollama.port];

  lab = {
    site = {
      hostIp = "192.168.10.180";
      internalIp = "10.10.0.180";
    };

    nvidia.exporter.enable = true;
  };

  system.stateVersion = "26.11";
}
