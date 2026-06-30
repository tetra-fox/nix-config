# declaratively register jellyfin as a "Connect" notification in sonarr/radarr so
# that on import/upgrade/rename the arr tells jellyfin to rescan the affected library
# (updateLibrary=true). same reconcile.sh as the download clients, against the
# /notification endpoint.
#
# reachability: jellyfin runs on the host, OUTSIDE the wg netns, so the arr reaches it
# at the host-side bridge address (same as sabnzbd). the api key is the shared
# apps/jellyfin_api_key secret -- the same value the jellyfin-apikey unit writes into
# jellyfin's ApiKeys table, so one secret is the single source of truth for the
# arr<->jellyfin link.
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

  # the arr import event is named differently per arr: sonarr fires onImportComplete,
  # radarr fires onDownload (its name for a completed import). both also rescan on
  # upgrade and rename. these are top-level keys on the notification object.
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
        port = 8096; # jellyfin default; services.jellyfin has no port option
        updateLibrary = true; # the toggle that triggers the library rescan
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
    # also declared by the jellyfin-apikey module on hosts that run jellyfin; declaring
    # it here too means the arr-side reconcile has it regardless of import order. sops
    # merges identical secret declarations.
    sops.secrets."apps/jellyfin_api_key" = {};

    systemd.services = lib.mapAttrs' mkUnit arrs;
  };
}
