{ username, ... }:

{
  virtualisation.docker = {
    enable = true;

    storageDriver = "overlay2";

    logDriver = "json-file";
    daemon.settings = {
      "log-opts" = {
        "max-size" = "10m";
        "max-file" = "3";
      };
    };

    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  users.users.${username} = {
    extraGroups = [
      "docker"
    ];
  };
}
