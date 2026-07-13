# immich (self-hosted photo library), native services.immich.
#
# data layout, and the reasoning behind it:
#   the photo library lives on megamax/immich (the store box's raidz1), NFS-mounted
#   here at /mnt/immich. postgres runs LOCALLY on this box, not over NFS: running
#   $PGDATA on nfs breaks postgres's fsync/locking assumptions and corrupts on a
#   network blip. so the db is local, the library is remote, and they'd normally
#   drift on restore.
#
#   the fix is immich's own backup: the server runs pg_dumpall|gzip on a schedule and
#   writes it to <mediaLocation>/backups, i.e. onto megamax/immich next to the photos.
#   a single restic snapshot of megamax/immich (taken on the store box) therefore
#   captures the library AND the db dump together, consistent by construction. on
#   restore you load the dump and immich re-indexes the photos, which is immich's
#   designed recovery path. no cross-box atomic snapshot, no postgres on nfs.
#
#   the vectorchord vector extension is enabled automatically by the nixpkgs module.
{
  config,
  lib,
  fleet,
  nixosConfigurations,
  ...
}: let
  cfg = config.lab.immich;
  topo = import fleet.topology {inherit lib;} {
    inherit nixosConfigurations;
    hostName = config.networking.hostName;
  };
in {
  options.lab.immich = {
    enable = lib.mkEnableOption "immich photo library";

    mediaLocation = lib.mkOption {
      type = lib.types.path;
      default = "/mnt/immich";
      description = ''
        where immich stores the library and its db-dump backups. an NFS mount of
        megamax/immich from the store box. immich writes library/ and backups/ under here.
      '';
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 990;
      description = ''
        pinned immich uid. the NFS export squashes on uid not name, so this must line
        up with the owner the store box gives /mnt/megamax/immich. one below jellyfin's
        991 to avoid collision.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    lab.topology.provides = ["immich"];

    # pin the uid: the NFS export squashes on uid, and the module otherwise
    # auto-allocates it, which would drift from the store box's export owner
    users.users.immich.uid = cfg.uid;

    services.immich = {
      enable = true;
      mediaLocation = cfg.mediaLocation;
      # bind to all interfaces so the edge caddy can reach it; the port is only
      # opened to this site's edge hosts via the firewall rule below, not the VLAN
      host = "0.0.0.0";
      openFirewall = false;
      # database.enable + redis.enable default true: both run locally on this box.
      # vectorchord is enabled automatically by the module.
      machine-learning.enable = true; # cpu inference, no accelerationDevices set
    };

    # reach immich from this site's edge (caddy) hosts only, source-scoped via nftables.
    # caddy proxies from its own box IP, not the VIP, so allow every edge host's real IP.
    networking.firewall.extraInputRules =
      lib.concatMapStringsSep "\n" (
        ip: "ip saddr ${ip} tcp dport ${toString config.services.immich.port} accept"
      )
      topo.edgeHostIps;
  };
}
