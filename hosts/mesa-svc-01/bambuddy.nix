# bambu printer archive and queue. sqlite in the data dir, oidc through authentik
{
  config,
  lib,
  topo,
  ...
}: let
  port = 8000;
  dataDir = "${config.lab.site.dataDir}/bambuddy";
  fqdn = "bb.${config.lab.site.domain}";
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

  systemd.tmpfiles.rules = ["d ${dataDir} 0750 bambuddy bambuddy -"];

  sops.secrets."apps/bambuddy_oidc_client_secret" = {};

  sops.templates."bambuddy.env" = {
    content = ''
      BAMBUDDY_OIDC_CLIENT_SECRET=${config.sops.placeholder."apps/bambuddy_oidc_client_secret"}
    '';
    restartUnits = ["podman-bambuddy.service"];
  };

  virtualisation.oci-containers.containers.bambuddy = {
    # full patch tag: no podman-auto-update, and upstream's releases can need manual migrations
    image = "ghcr.io/maziggy/bambuddy:1.2.5.7";
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

      BAMBUDDY_OIDC_NAME = "Authentik";
      BAMBUDDY_OIDC_ISSUER_URL = "${topo.authServerUrl}/application/o/bambuddy/";
      BAMBUDDY_OIDC_CLIENT_ID = "bambuddy";
      BAMBUDDY_OIDC_AUTO_CREATE_USERS = "true";
      # authentik only lets sysadmin into the app
      BAMBUDDY_OIDC_GROUP_MAPPING = builtins.toJSON {sysadmin = "Administrators";};
    };
  };
}
