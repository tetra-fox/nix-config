# split out so a pure client can import just the options
{
  config,
  lib,
  pkgs,
  fleet,
  caps,
  ...
}: let
  cfg = config.lab.postgres;
in {
  # from the plain enable flags, so topology finds db hosts without importing the server or HA module
  config.lab.topology.provides =
    lib.optional cfg.server.enable caps.dbServer.name
    ++ lib.optional cfg.ha.enable caps.dbHaNode.name
    ++ lib.optional cfg.client.enable caps.dbClient.name;

  # a role, so both the single-server unit and the HA reconcile create it
  config.lab.postgres.roles = lib.mkIf cfg.admin.enable {
    admin = {
      passwordSecret = cfg.admin.passwordSecret;
      clauses = {
        superuser = true;
        createdb = true;
        createrole = true;
        replication = true;
      };
    };
  };

  options.lab.postgres = {
    server.enable = lib.mkEnableOption "run the postgres server on this host";

    client.enable = lib.mkEnableOption "this host is a postgres client (server allow-lists its IP)";

    openFirewall = lib.mkEnableOption "5432/tcp in the host firewall";

    # here, not in the HA module, so topology can read ha.enable/ha.vip without importing it
    ha = {
      enable = lib.mkEnableOption "run the Patroni HA postgres stack on this host (instead of server.enable)";

      vip = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          the floating virtual IP HAProxy binds and clients reach. every HA node in the
          site declares the same value; the topology dbEndpointIp derive returns it so
          clients point at the VIP, which always routes to the current primary. on the
          internal VLAN (east-west db traffic).
        '';
      };

      scope = lib.mkOption {
        type = lib.types.str;
        default = "${fleet.site-prefix config.networking.hostName}-pg";
        description = "Patroni cluster name (scope). shared by every node in the cluster. also names the etcd cluster token (<scope>-etcd).";
      };

      virtualRouterId = lib.mkOption {
        type = lib.types.int;
        default = 51;
        description = "VRRP router id for the db VIP, unique per L2 segment (see lab.vrrp.virtualRouterId).";
      };

      bootstrapHold = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "install the HA stack but leave etcd/patroni/haproxy/keepalived stopped (for a coordinated cluster bootstrap)";
      };
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql_17;
    };

    extraAllowedCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "additional pg_hba CIDRs beyond the derived fleet clients (admin VLAN, external tools)";
    };

    passwordUnits = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
    };

    # replication isn't backup: a dropped db is dropped on every standby too
    backup = {
      enable = lib.mkEnableOption "a nightly pg_dumpall of every database + globals into backup.dir";

      dir = lib.mkOption {
        type = lib.types.str;
        default = "${config.lab.site.dataDir}/postgres-dumps";
        description = "where dumps land. the single-server module creates it; an NFS-backed dir must already exist on the export";
      };

      keep = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "dump generations to keep in dir; older ones are pruned after each run";
      };

      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "14:00";
        description = "dump time (servers run UTC). the default lands before the store box's 14:30 restic run, see SCHEDULE.md";
      };
    };

    admin = {
      enable = lib.mkEnableOption "an `admin` superuser role for dbeaver/psql access";
      passwordSecret = lib.mkOption {
        type = lib.types.str;
        default = "postgres/admin_pass";
      };
    };

    roles = lib.mkOption {
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          passwordSecret = lib.mkOption {type = lib.types.str;};
          clauses = lib.mkOption {
            type = lib.types.attrsOf lib.types.bool;
            default = {};
          };
          owns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
        };
      });
    };
  };
}
