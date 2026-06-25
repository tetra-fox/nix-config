# declaratively register qbittorrent + sabnzbd as download clients inside sonarr
# and radarr. the arrs store download clients as rows in their own db, not in a
# config file, so there's nothing nixos can write directly; instead a oneshot per
# arr reconciles the live list against the set declared here via the /downloadclient
# REST api. shared by every host that imports the arr-stack, so all sites get the
# same clients.
#
# reachability (all addresses are from the arr's point of view):
#   - this oneshot runs on the host (like recyclarr) and hits each arr at the
#     netns-internal address, same as recyclarr does
#   - qbittorrent lives in the same netns as the arrs, so the arr reaches it at
#     127.0.0.1:<webuiPort> with no auth (qbit has LocalHostAuth=false)
#   - sabnzbd lives on the host OUTSIDE the netns, so the arr reaches it at the
#     host-side bridge address (config.vpnNamespaces.wg.bridgeAddress)
#
# reconcile semantics: clients whose name isn't declared here are deleted (drift
# is pruned), declared clients are created if missing or updated in place if
# present. idempotent, so it's safe to run on every rebuild.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.lab.arrStack;
  vpn = config.vpnNamespaces.wg;

  mkSecureCurl = import ./mk-secure-curl.nix {inherit lib pkgs;};

  # the arr's own localhost inside the netns reaches qbit; the host bridge address
  # reaches sab (which runs outside the netns).
  qbitHost = "127.0.0.1";
  qbitPort = config.services.qbittorrent.webuiPort;
  sabHost = vpn.bridgeAddress;
  sabPort = config.services.sabnzbd.settings.misc.port;

  # the credential name the api key is loaded under inside the unit. the file is
  # populated by LoadCredential from the sops secret path.
  sabKeyCred = "sab-api-key";
  sabKeyFile = svc: "/run/credentials/${svc}-downloadclients.service/${sabKeyCred}";

  # the download-client category field is named differently per arr in the schema:
  # sonarr calls it tvCategory, radarr calls it movieCategory. the value matches a
  # category defined in sabnzbd.nix / a qbit label, which we keep == the arr name.
  categoryField = {
    sonarr = "tvCategory";
    radarr = "movieCategory";
  };

  # the two download clients, expressed as the field overrides each needs on top of
  # its schema. category field name differs per arr; everything else is shared.
  #   - implementationName matches the schema's implementationName (qBittorrent / SABnzbd)
  #   - fields named here override the schema defaults; anything left out keeps the
  #     schema default (e.g. qbit's useSsl=false, sab's various toggles)
  clientsFor = arr: [
    {
      name = "qBittorrent";
      implementationName = "qBittorrent";
      # qbit api key not needed: it's reached over netns-localhost with auth off.
      fields = {
        host = qbitHost;
        port = qbitPort;
        ${categoryField.${arr}} = arr; # "sonarr" / "radarr"
      };
    }
    {
      name = "SABnzbd";
      implementationName = "SABnzbd";
      # sab's category must match a category defined in sabnzbd.nix (radarr/sonarr).
      # the api key is injected at runtime from the credential file, never inlined.
      apiKeyFrom = sabKeyFile arr;
      fields = {
        host = sabHost;
        port = sabPort;
        ${categoryField.${arr}} = arr;
      };
    }
  ];

  # build the reconcile script for one arr. takes the arr name, the in-netns api
  # url base, and the path to the arr's own api key (used to authenticate to the arr).
  mkReconcile = {
    arr,
    baseUrl,
    arrKeyFile,
  }: let
    clients = clientsFor arr;

    # json of the declared client names, for the prune step
    declaredNames = builtins.toJSON (map (c: c.name) clients);

    # per-client apply: take a base object (existing client or fresh schema),
    # overwrite its .fields[].value for each override and its top-level name, then
    # POST (create) or PUT (update). the sab api key is spliced in with jq --rawfile
    # so it's read from the credential file at runtime, not embedded in the store.
    mkApply = c: let
      overridesJson = builtins.toJSON (c.fields // {name = c.name;});
      # for sab, read the api key from its credential file into a jq var and set the
      # apiKey field from it. qbit has no key, so this is empty.
      keyRawfile = lib.optionalString (c ? apiKeyFrom) "--rawfile sabKey ${lib.escapeShellArg c.apiKeyFrom}";
      keyAssign = lib.optionalString (c ? apiKeyFrom) ''| .fields |= map(if .name == "apiKey" then .value = ($sabKey | sub("\\n+$"; "")) else . end)'';
    in ''
      echo "reconciling download client ${c.name} in ${arr}"

      OVERRIDES=${lib.escapeShellArg overridesJson}
      EXISTING=$(echo "$CLIENTS" | ${lib.getExe pkgs.jq} -c --arg n ${lib.escapeShellArg c.name} '.[] | select(.name == $n)' || true)

      if [ -n "$EXISTING" ]; then
        ID=$(echo "$EXISTING" | ${lib.getExe pkgs.jq} -r '.id')
        BODY=$(echo "$EXISTING" | ${lib.getExe pkgs.jq} \
          --argjson o "$OVERRIDES" ${keyRawfile} '
            .name = $o.name
            | .fields |= map(if $o[.name] != null then .value = $o[.name] else . end)
            ${keyAssign}
          ')
        ${
        mkSecureCurl arrKeyFile {
          url = "${baseUrl}/downloadclient/$ID";
          method = "PUT";
          dataVar = "BODY";
          extraArgs = "-Sf";
        }
      } >/dev/null
        echo "  updated ${c.name} (id $ID)"
      else
        SCHEMA=$(echo "$SCHEMAS" | ${lib.getExe pkgs.jq} -c --arg i ${lib.escapeShellArg c.implementationName} '.[] | select(.implementationName == $i)')
        if [ -z "$SCHEMA" ]; then
          echo "  ERROR: no schema for ${c.implementationName} in ${arr}" >&2
          exit 1
        fi
        BODY=$(echo "$SCHEMA" | ${lib.getExe pkgs.jq} \
          --argjson o "$OVERRIDES" ${keyRawfile} '
            .name = $o.name
            | .fields |= map(if $o[.name] != null then .value = $o[.name] else . end)
            ${keyAssign}
          ')
        ${
        mkSecureCurl arrKeyFile {
          url = "${baseUrl}/downloadclient";
          method = "POST";
          dataVar = "BODY";
          extraArgs = "-Sf";
        }
      } >/dev/null
        echo "  created ${c.name}"
      fi
    '';
  in ''
    set -euo pipefail

    # wait for the arr's api to answer before touching it. the unit ordering only
    # guarantees the process started, not that the http listener is up yet. the key
    # goes in the header (via mkSecureCurl), not the query string, so it stays out of
    # the arr's request log.
    ${
      mkSecureCurl arrKeyFile {
        url = "${baseUrl}/system/status";
        extraArgs = "--retry 30 --retry-delay 2 --retry-connrefused -o /dev/null";
      }
    } || { echo "ERROR: ${arr} api never came up" >&2; exit 1; }

    SCHEMAS=$(${
      mkSecureCurl arrKeyFile {
        url = "${baseUrl}/downloadclient/schema";
        extraArgs = "-Sf";
      }
    })
    CLIENTS=$(${
      mkSecureCurl arrKeyFile {
        url = "${baseUrl}/downloadclient";
        extraArgs = "-Sf";
      }
    })

    # prune any live client not in the declared set
    DECLARED=${lib.escapeShellArg declaredNames}
    echo "$CLIENTS" | ${lib.getExe pkgs.jq} -c '.[]' | while IFS= read -r dc; do
      NAME=$(echo "$dc" | ${lib.getExe pkgs.jq} -r '.name')
      ID=$(echo "$dc" | ${lib.getExe pkgs.jq} -r '.id')
      if ! echo "$DECLARED" | ${lib.getExe pkgs.jq} -e --arg n "$NAME" 'index($n)' >/dev/null; then
        echo "pruning undeclared download client $NAME (id $ID) from ${arr}"
        ${
      mkSecureCurl arrKeyFile {
        url = "${baseUrl}/downloadclient/$ID";
        method = "DELETE";
        extraArgs = "-Sf";
      }
    } >/dev/null || echo "  warning: failed to delete $NAME"
      fi
    done

    ${lib.concatMapStringsSep "\n" mkApply clients}

    echo "${arr} download clients reconciled"
  '';

  # the arrs we register clients into, with their in-netns api base url and the sops
  # secret holding each one's own api key.
  arrs = {
    sonarr = {
      baseUrl = "http://${vpn.namespaceAddress}:${toString cfg.lanProxyPorts.sonarr}/api/v3";
      apiKeySecret = "apps/sonarr_api_key";
    };
    radarr = {
      baseUrl = "http://${vpn.namespaceAddress}:${toString cfg.lanProxyPorts.radarr}/api/v3";
      apiKeySecret = "apps/radarr_api_key";
    };
  };

  mkUnit = arr: spec: let
    arrKeyCred = "${arr}-api-key";
    arrKeyFile = "/run/credentials/${arr}-downloadclients.service/${arrKeyCred}";
  in {
    name = "${arr}-downloadclients";
    value = {
      description = "register download clients in ${arr} via api";
      after = ["${arr}.service" "recyclarr.service"];
      wants = ["${arr}.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # the arr's own key authenticates us to it; sab's key gets written into
        # sab's downloadclient field. both come from sops secrets via credentials,
        # so they're decrypted into /run/credentials and never hit the store.
        LoadCredential = [
          "${arrKeyCred}:${config.sops.secrets.${spec.apiKeySecret}.path}"
          "${sabKeyCred}:${config.sops.secrets."apps/sabnzbd_api_key".path}"
        ];
        ExecStart = pkgs.writeShellScript "${arr}-downloadclients.sh" (mkReconcile {
          inherit arr arrKeyFile;
          inherit (spec) baseUrl;
        });
      };
    };
  };
in {
  config = {
    systemd.services = lib.mapAttrs' mkUnit arrs;
  };
}
