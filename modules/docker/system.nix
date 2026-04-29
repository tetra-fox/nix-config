{
  config,
  lib,
  username,
  ...
}: let
  cfg = config.lab.docker;
in {
  options.lab.docker.watchtower.enable = lib.mkEnableOption "watchtower";

  config = {
    virtualisation = {
      docker = {
        enable = true;
        storageDriver = "overlay2";
        logDriver = "json-file";
        daemon.settings.log-opts = {
          "max-size" = "10m";
          "max-file" = "3";
        };
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };
      # default backend for services.virtualisation.oci-containers.<x>.
      oci-containers = {
        backend = "docker";

        # nightly pull newer images for any running container, recreate, prune
        containers = lib.mkIf cfg.watchtower.enable {
          watchtower = {
            image = "ghcr.io/nicholas-fedor/watchtower";
            volumes = ["/var/run/docker.sock:/var/run/docker.sock"];
            cmd = ["--cleanup" "-s" "0 0 11 * * *"]; # 11am local time (UTC for servers)
            environment.TZ = config.time.timeZone;
          };
        };
      };
    };

    users.users.${username}.extraGroups = ["docker"];

    # trust traffic from docker bridges
    networking.firewall = {
      trustedInterfaces = ["docker0"];
      extraInputRules = ''
        iifname "br-*" accept
      '';
    };
  };
}
