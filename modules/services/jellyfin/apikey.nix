# jellyfin api keys are db rows with no config hook, apikey.sh writes ours in
{
  config,
  lib,
  pkgs,
  ...
}: let
  cred = "jellyfin-api-key";

  apikey = pkgs.writeShellApplication {
    name = "jellyfin-apikey";
    runtimeInputs = [pkgs.sqlite];
    text = builtins.readFile ./apikey.sh;
  };
in {
  config = {
    sops.secrets."apps/jellyfin_api_key" = {};

    systemd.services.jellyfin-apikey = {
      description = "Set *arr API key in Jellyfin";
      after = ["jellyfin.service"];
      wants = ["jellyfin.service"];
      wantedBy = ["multi-user.target"];
      environment = {
        JELLYFIN_DB = "${config.services.jellyfin.dataDir}/data/jellyfin.db";
        KEY_NAME = "arr";
        KEY_FILE = "/run/credentials/jellyfin-apikey.service/${cred}";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.services.jellyfin.user;
        Group = config.services.jellyfin.group;
        LoadCredential = ["${cred}:${config.sops.secrets."apps/jellyfin_api_key".path}"];
        ExecStart = lib.getExe apikey;
      };
    };
  };
}
