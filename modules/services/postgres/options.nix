# split from the server module so a pure client can import just these options.
{
  lib,
  pkgs,
  ...
}: {
  options.lab.postgres = {
    server.enable = lib.mkEnableOption "run the postgres server on this host";

    client.enable = lib.mkEnableOption "this host is a postgres client (server allow-lists its IP)";

    openFirewall = lib.mkEnableOption "5432/tcp in the host firewall";

    # declared here, not in the HA module, so the site-topology derive can read ha.enable/ha.vip
    # without importing that module.
    ha = {
      enable = lib.mkEnableOption "run the Patroni HA postgres stack on this host (instead of server.enable)";

      vip = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          the floating virtual IP HAProxy binds and clients reach. every HA node in the
          site declares the same value; the site-topology dbEndpointIp derive returns it so
          clients point at the VIP, which always routes to the current primary. on the
          internal VLAN (east-west db traffic).
        '';
      };

      scope = lib.mkOption {
        type = lib.types.str;
        default = "mesa-pg";
        description = "Patroni cluster name (scope). shared by every node in the cluster.";
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
