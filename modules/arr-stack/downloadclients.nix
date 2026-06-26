# declaratively register qbittorrent + sabnzbd as download clients inside sonarr
# and radarr. the arrs store download clients as rows in their own db, not in a
# config file, so a oneshot per arr reconciles the live list against the set declared
# here via the /downloadclient rest api (reconcile.sh does the work). shared by every
# host that imports the arr-stack, so all sites get the same clients.
#
# reachability (all addresses are from the arr's point of view):
#   - the oneshot runs on the host (like recyclarr) and hits each arr at the
#     netns-internal address, same as recyclarr does
#   - qbittorrent lives in the same netns as the arrs, so the arr reaches it at
#     127.0.0.1:<webuiPort> with no auth (qbit has LocalHostAuth=false)
#   - sabnzbd lives on the host OUTSIDE the netns, so the arr reaches it at the
#     host-side bridge address (config.vpnNamespaces.wg.bridgeAddress)
#
# reconcile semantics: clients not declared here are deleted, declared clients are
# created if missing or updated in place. idempotent, safe on every rebuild.
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

  # the download-client category field is named differently per arr in the schema:
  # sonarr calls it tvCategory, radarr calls it movieCategory. the value matches a
  # category defined in sabnzbd.nix / a qbit label, which we keep == the arr name.
  categoryField = {
    sonarr = "tvCategory";
    radarr = "movieCategory";
  };

  clientsFor = arr: [
    {
      name = "qBittorrent";
      schemaName = "qBittorrent";
      # the /downloadclient/schema template defaults enable=false, so a freshly
      # created client would be disabled; force it on. (updates preserve the live
      # value, but a from-scratch host takes the create path.)
      top = {enable = true;};
      # qbit api key not needed: it's reached over netns-localhost with auth off.
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
      # sab's category must match a category defined in sabnzbd.nix (radarr/sonarr).
      # the api key is read at runtime from the credential file, never inlined.
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
        # the arr's own key authenticates us to it; sab's key gets written into sab's
        # downloadclient field. both come from sops via credentials, decrypted into
        # /run/credentials, never in the store.
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
