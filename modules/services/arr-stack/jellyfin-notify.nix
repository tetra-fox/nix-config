# arrs tell jellyfin to rescan on import/upgrade/rename. apps/jellyfin_api_key is the
# same key jellyfin-apikey writes into jellyfin's ApiKeys table
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

  jfKeyCred = "jellyfin-api-key";
  jfKeyFile = arr: "/run/credentials/${arr}-jellyfin-notify.service/${jfKeyCred}";

  # same event, different names
  importToggle = {
    sonarr = "onImportComplete";
    radarr = "onDownload";
  };

  notificationFor = arr: [
    {
      name = "Jellyfin";
      schemaName = "MediaBrowser";
      top = {
        ${importToggle.${arr}} = true;
        onUpgrade = true;
        onRename = true;
      };
      secretField = "apiKey";
      secretFile = jfKeyFile arr;
      fields = {
        host = vpn.bridgeAddress;
        # fails eval if this host doesn't run jellyfin
        port = config.lab.jellyfin.port;
        updateLibrary = true;
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
    itemsFile = pkgs.writeText "${arr}-jellyfin-notify.json" (builtins.toJSON (notificationFor arr));
  in {
    name = "${arr}-jellyfin-notify";
    value = {
      description = "register jellyfin rescan notification in ${arr} via api";
      after = ["${arr}.service"];
      wants = ["${arr}.service"];
      wantedBy = ["multi-user.target"];
      environment = {
        BASE_URL = "http://${vpn.namespaceAddress}:${toString spec.port}/api/v3";
        RESOURCE = "notification";
        SCHEMA_KEY = "implementation";
        LABEL = "notification";
        ARR_KEY_FILE = "/run/credentials/${arr}-jellyfin-notify.service/${arrKeyCred}";
        ITEMS_FILE = itemsFile;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = [
          "${arrKeyCred}:${config.sops.secrets.${spec.apiKeySecret}.path}"
          "${jfKeyCred}:${config.sops.secrets."apps/jellyfin_api_key".path}"
        ];
        ExecStart = lib.getExe reconcile;
      };
    };
  };
in {
  config = {
    # also declared by jellyfin-apikey, identical decls merge
    sops.secrets."apps/jellyfin_api_key" = {};

    systemd.services = lib.mapAttrs' mkUnit arrs;
  };
}
