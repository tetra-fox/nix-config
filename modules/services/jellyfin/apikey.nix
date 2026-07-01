# jellyfin api keys are rows in jellyfin.db (ApiKeys), not config, so there's no startup
# hook to set one from a secret. a oneshot upserts a row whose AccessToken equals our
# secret (apikey.sh); jellyfin compares the token verbatim, so it authenticates normally.
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
      description = "ensure the shared 'arr' api key row exists in jellyfin.db";
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
