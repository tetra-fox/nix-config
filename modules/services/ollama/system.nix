{
  config,
  pkgs,
  ...
}: {
  services.ollama = {
    enable = true;
    # ollama-cuda for the rtx 3090; the default package is cpu-only
    package = pkgs.ollama-cuda;
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "30m";
      OLLAMA_CONTEXT_LENGTH = "65536";
    };
  };

  services.open-webui = {
    enable = true;
    # the ollama endpoint open-webui talks to
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:${toString config.services.ollama.port}";
      # single-user desktop stack, skip the login wall
      WEBUI_AUTH = "False";
      # no outbound telemetry (re-stated because setting environment replaces the module defaults)
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
    };
  };

  # open-webui defaults to 8080; ollama listens on 11434. both bind 127.0.0.1,
  # so nothing leaves the box and no firewall port is opened.
  assertions = [
    {
      assertion = config.services.open-webui.host == "127.0.0.1" && config.services.ollama.host == "127.0.0.1";
      message = "modules.services.ollama assumes a localhost-only stack; if you bind either service to a routable address, add auth (WEBUI_AUTH) and firewall handling before removing this assertion";
    }
  ];
}
