{
  config,
  lib,
  pkgs,
  siteData,
  ...
}: let
  cfg = config.lab.postgres;

  # one systemd oneshot per role: ALTER USER <name> WITH PASSWORD :'pass'
  # plus, for each db in role.owns, ALTER DATABASE OWNER + ALTER SCHEMA
  # public OWNER. PG 15+ tightened the public schema so GRANT ALL ON
  # DATABASE alone isn't enough; the schema's owner has to be the role
  # that wants to CREATE TABLE there.
  mkRoleUnit = name: role: {
    description = "Set ${name} postgres role password + ownership from sops";
    after = ["postgresql-setup.service"];
    requires = ["postgresql-setup.service"];
    wantedBy = ["postgresql.service"];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      RemainAfterExit = true;
      LoadCredential = "pgpass:${config.sops.secrets.${role.passwordSecret}.path}";
    };
    # heredoc so embedded "${db-with-hyphen}" survives bash; EOF unquoted so
    # $CREDENTIALS_DIRECTORY in the -v flag still expands.
    script = let
      ownerStmts = lib.concatMapStringsSep "\n" (db: ''
        ALTER DATABASE "${db}" OWNER TO ${name};
        \connect "${db}"
        ALTER SCHEMA public OWNER TO ${name};'')
      role.owns;
    in ''
      ${cfg.package}/bin/psql -v "pass=$(cat $CREDENTIALS_DIRECTORY/pgpass)" <<EOF
      ALTER USER ${name} WITH ENCRYPTED PASSWORD :'pass';
      ${ownerStmts}
      EOF
    '';
  };
in {
  options.lab.postgres = {
    openFirewall = lib.mkEnableOption "5432/tcp in the host firewall";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql_17;
    };

    allowedCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
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

  config = {
    lab.postgres = {
      passwordUnits = lib.mapAttrs (name: _: "postgresql-set-${name}-password.service") cfg.roles;

      roles = lib.mkIf cfg.admin.enable {
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
    };

    services.postgresql = {
      enable = true;
      package = cfg.package;
      dataDir = "${siteData}/postgresql/${cfg.package.psqlSchema}";
      enableTCPIP = true;
      settings.listen_addresses = "*";
      authentication =
        lib.optionalString (cfg.allowedCidrs != [])
        (lib.concatMapStringsSep "\n" (cidr: "host all all ${cidr} scram-sha-256") cfg.allowedCidrs + "\n");

      ensureUsers =
        lib.mapAttrsToList (name: role: {
          inherit name;
          ensureClauses = role.clauses;
        })
        cfg.roles;

      # every db a role owns is a db that should exist. consumers can still
      # add ensureDatabases entries for unowned dbs (none today).
      ensureDatabases = lib.unique (lib.concatMap (r: r.owns) (lib.attrValues cfg.roles));
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [5432];

    # mkDefault so a consumer that also declares the same secret path (e.g.
    # an env file template) wins and we don't conflict.
    sops.secrets =
      lib.mapAttrs' (
        name: role:
          lib.nameValuePair role.passwordSecret (lib.mkDefault {})
      )
      cfg.roles;

    systemd.services =
      lib.mapAttrs' (
        name: role:
          lib.nameValuePair "postgresql-set-${name}-password" (mkRoleUnit name role)
      )
      cfg.roles;
  };
}
