# bambu printer archive and queue. sqlite in the data dir, oidc through authentik
{
  config,
  lib,
  topo,
  ...
}: let
  # full patch tag: no podman-auto-update, and upstream's releases can need manual migrations.
  # the slicer sidecar is published per bambuddy release under the same version
  version = "1.2.5.7";
  port = 8000;
  dataDir = "${config.lab.site.dataDir}/bambuddy";
  fqdn = "bb.${config.lab.site.domain}";
  # 3000 and 3002 belong to bambuddy's virtual printers
  slicerPort = 3003;
  slicerDataDir = "${config.lab.site.dataDir}/orca-slicer-api";
in {
  lab.topology.routes = [
    {
      host = fqdn;
      inherit port;
      middlewares = ["lan_only"];
    }
  ];

  # the image's entrypoint chowns /app/data to PUID:PGID, then drops to them
  users = {
    users.bambuddy = {
      isSystemUser = true;
      uid = 969;
      group = "bambuddy";
    };
    groups.bambuddy.gid = 969;
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 bambuddy bambuddy -"
    # the sidecar image runs as root
    "d ${slicerDataDir} 0750 root root -"
  ];

  sops.secrets."apps/bambuddy_oidc_client_secret" = {};

  sops.templates."bambuddy.env" = {
    content = ''
      BAMBUDDY_OIDC_CLIENT_SECRET=${config.sops.placeholder."apps/bambuddy_oidc_client_secret"}
    '';
    restartUnits = ["podman-bambuddy.service"];
  };

  # orcaslicer's cli behind http, for bambuddy's server-side slice
  virtualisation.oci-containers.containers.orca-slicer-api = {
    image = "ghcr.io/maziggy/orca-slicer-api:bambuddy-${version}";
    # loopback only, bambuddy is its one client
    ports = ["127.0.0.1:${toString slicerPort}:3000"];
    volumes = ["${slicerDataDir}:/app/data"];
  };

  virtualisation.oci-containers.containers.bambuddy = {
    image = "ghcr.io/maziggy/bambuddy:${version}";
    # upstream's supported mode on linux, virtual printers bind their own set of ports.
    # those stay closed, the firewall only admits the edge hosts to the route's port
    networks = ["host"];
    volumes = ["${dataDir}:/app/data"];
    environmentFiles = [config.sops.templates."bambuddy.env".path];
    environment = {
      TZ = "America/Los_Angeles";
      PUID = toString config.users.users.bambuddy.uid;
      PGID = toString config.users.groups.bambuddy.gid;
      PORT = toString port;
      # stdout only, journald rotates it
      LOG_TO_FILE = "false";
      # base of the oidc redirect uri
      APP_URL = "https://${fqdn}";
      # login rate limits key on the client address, not the edge's
      TRUSTED_PROXY_IPS = lib.concatStringsSep "," topo.edgeHostIps;
      # host networking, so the sidecar's loopback port is reachable
      SLICER_API_URL = "http://127.0.0.1:${toString slicerPort}";

      BAMBUDDY_OIDC_NAME = "Authentik";
      BAMBUDDY_OIDC_ISSUER_URL = "${topo.authServerUrl}/application/o/bambuddy/";
      BAMBUDDY_OIDC_CLIENT_ID = "bambuddy";
      BAMBUDDY_OIDC_AUTO_CREATE_USERS = "true";
      # authentik releases only these to bambuddy, see oidc-providers.yaml
      BAMBUDDY_OIDC_SCOPES = "openid profile";
      # authentik admits exactly these three groups to the app
      BAMBUDDY_OIDC_GROUP_MAPPING = builtins.toJSON {
        sysadmin = "Administrators";
        printer_admin = "Operators";
        local_users = "Viewers";
      };
    };
  };
}
