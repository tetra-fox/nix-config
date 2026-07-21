# split from the server module so a pure client can import just these options.
{
  config,
  lib,
  pkgs,
  fleet,
  caps,
  ...
}: let
  cfg = config.lab.postgres;
  sitePrefix = import fleet.site-prefix {inherit lib;};
in {
  # advertise the db capabilities from the plain enable flags, so the topology layer discovers this
  # host without importing the server or HA module. imported by server, HA, and pure clients
  # alike, so it's the one place every db-role host passes through.
  config.lab.topology.provides =
    lib.optional cfg.server.enable caps.dbServer.name
    ++ lib.optional cfg.ha.enable caps.dbHaNode.name
    ++ lib.optional cfg.client.enable caps.dbClient.name;

  options.lab.postgres = {
    server.enable = lib.mkEnableOption "run the postgres server on this host";

    client.enable = lib.mkEnableOption "this host is a postgres client (server allow-lists its IP)";

    openFirewall = lib.mkEnableOption "5432/tcp in the host firewall";

    # declared here, not in the HA module, so the topology derive can read ha.enable/ha.vip
    # without importing that module.
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
        # <site>-pg, so a second site gets its own cluster name without setting anything
        default = "${sitePrefix config.networking.hostName}-pg";
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
