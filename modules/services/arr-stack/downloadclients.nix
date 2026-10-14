# download clients are db rows in the arrs, so reconcile.sh declares them via the api
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.arrStack;
  vpn = config.vpnNamespaces.wg;

  reconcile = pkgs.writeShellApplication {
    name = "arr-reconcile";
    runtimeInputs = [pkgs.curl pkgs.jq];
    text = builtins.readFile ./reconcile.sh;
  };

  sabKeyCred = "sab-api-key";
  sabKeyFile = arr: "/run/credentials/${arr}-downloadclients.service/${sabKeyCred}";

  # value must match a sabnzbd category / qbit label, both named after the arr
  categoryField = {
    sonarr = "tvCategory";
    radarr = "movieCategory";
  };

  clientsFor = arr: [
    {
      name = "qBittorrent";
      schemaName = "qBittorrent";
      # schema template defaults to disabled
      top = {enable = true;};
      # same netns, qbit has LocalHostAuth off
      fields = {
        host = "127.0.0.1";
        port = config.services.qbittorrent.webuiPort;
        ${categoryField.${arr}} = arr;
      };
    }
    {
      name = "SABnzbd";
      schemaName = "SABnzbd";
      top = {enable = true;};
      secretField = "apiKey";
      secretFile = sabKeyFile arr;
      fields = {
        host = vpn.bridgeAddress;
        port = config.services.sabnzbd.settings.misc.port;
        ${categoryField.${arr}} = arr;
      };
    }
  ];

  arrs = {
    sonarr = {
      port = cfg.lanProxyPorts.sonarr;
      apiKeySecret = "apps/sonarr_api_key";
    };
    radarr = {
      port = cfg.lanProxyPorts.radarr;
      apiKeySecret = "apps/radarr_api_key";
    };
  };

  mkUnit = arr: spec: let
    arrKeyCred = "${arr}-api-key";
    itemsFile = pkgs.writeText "${arr}-downloadclients.json" (builtins.toJSON (clientsFor arr));
  in {
    name = "${arr}-downloadclients";
    value = {
      description = "register download clients in ${arr} via api";
      after = ["${arr}.service" "recyclarr.service"];
      wants = ["${arr}.service"];
      wantedBy = ["multi-user.target"];
      environment = {
        BASE_URL = "http://${vpn.namespaceAddress}:${toString spec.port}/api/v3";
        RESOURCE = "downloadclient";
        SCHEMA_KEY = "implementationName";
        LABEL = "download client";
        ARR_KEY_FILE = "/run/credentials/${arr}-downloadclients.service/${arrKeyCred}";
        ITEMS_FILE = itemsFile;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = [
          "${arrKeyCred}:${config.sops.secrets.${spec.apiKeySecret}.path}"
          "${sabKeyCred}:${config.sops.secrets."apps/sabnzbd_api_key".path}"
        ];
        ExecStart = lib.getExe reconcile;
      };
    };
  };
in {
  config = {
    systemd.services = lib.mapAttrs' mkUnit arrs;
  };
}
