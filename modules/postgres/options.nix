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
