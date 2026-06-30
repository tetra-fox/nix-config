# postgres option declarations, split out so a pure CLIENT (e.g. authentik) can import
# just this contract -- setting lab.postgres.client.enable -- without dragging in the
# whole server module (services.postgresql, the role oneshots, the firewall hole). the
# server lives in system.nix, which imports this. mirrors monitoring/registry.nix.
{
  lib,
  pkgs,
  ...
}: {
  options.lab.postgres = {
    # this host runs the postgres server (mirrors lab.monitoring.server.enable). one per
    # site today; the site-topology derive reads this flag to point clients at its IP, so
    # an HA cluster later just moves which host/endpoint the flag-derived address resolves
    # to without touching any client.
    server.enable = lib.mkEnableOption "run the postgres server on this host";

    # this host connects to the site's postgres server. the server folds every client's
    # hostIp into its pg_hba allow-list via the dbClientCidrs derive, so adding a client
    # box is just setting this flag -- no edit to the server's config.
    client.enable = lib.mkEnableOption "this host is a postgres client (server allow-lists its IP)";

    openFirewall = lib.mkEnableOption "5432/tcp in the host firewall";

    # high-availability data tier: a Patroni + etcd + HAProxy + keepalived cluster instead
    # of the single services.postgresql server. declared here (not in the postgres-ha module)
    # so the site-topology derive can read ha.enable/ha.vip as plain INPUT attrs without
    # importing the HA module. a host sets ha.enable XOR server.enable -- the two server
    # backends are mutually exclusive (Patroni owns postgres end to end and asserts that
    # services.postgresql is off). the roles/extraAllowedCidrs contract above is shared:
    # the postgres-ha module reads the same cfg.roles to build Patroni's bootstrap + pg_hba.
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

      # bootstrap hold: install etcd/patroni but leave them stopped (not wantedBy
      # multi-user.target). used during a coordinated cutover so a freshly-installed db node
      # does NOT form a partial cluster before every member is present. with the 3-node
      # bootstrap, all members must come up together with the same initialCluster and
      # initialClusterState=new; a node that bootstrapped a smaller cluster first would
      # conflict. set true on the new nodes until cutover, then flip all members to false and
      # deploy together so etcd/patroni start with the full node set. haproxy/keepalived also
      # stay down (nothing to route to yet).
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

    # explicit extras the derive can't see: non-fleet sources like the admin VLAN or
    # external tooling. fleet clients should set lab.postgres.client.enable instead.
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
