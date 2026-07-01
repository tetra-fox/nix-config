# register qbittorrent + sabnzbd as download clients in sonarr/radarr. the arrs store
# download clients as db rows, not config, so a oneshot per arr reconciles the live list
# against the set declared here via the /downloadclient rest api (reconcile.sh).
#
# addresses are from the arr's point of view: qbit shares the netns so the arr reaches
# it at 127.0.0.1 with no auth (LocalHostAuth=false); sabnzbd is outside the netns so
# the arr reaches it at the host-side bridge address.
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

  # the category field is named per arr in the schema: sonarr tvCategory, radarr
  # movieCategory. its value must match a sabnzbd category / qbit label, kept == arr name
  categoryField = {
    sonarr = "tvCategory";
    radarr = "movieCategory";
  };

  clientsFor = arr: [
    {
      name = "qBittorrent";
      schemaName = "qBittorrent";
      # the schema template defaults enable=false, so force it on
      top = {enable = true;};
      # no api key: qbit is reached over netns-localhost with auth off
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
        # the arr key authenticates us to the arr; the sab key gets written into sab's
        # downloadclient field
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
