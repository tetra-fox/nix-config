{
  config,
  lib,
  pkgs,
  siteData,
  ...
}: let
  cfg = config.lab.postgres;

  # ALTER USER ... PASSWORD, plus ALTER DATABASE OWNER + ALTER SCHEMA public OWNER for each owned db.
  # pg 15+ needs the schema's owner to be the role that wants to CREATE TABLE in `public`.
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
    # heredoc lets "${db-with-hyphen}" reach psql intact; EOF unquoted so $CREDENTIALS_DIRECTORY expands
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

      ensureDatabases = lib.unique (lib.concatMap (r: r.owns) (lib.attrValues cfg.roles));
    };

    # dataDir is overridden under siteData. the unit's ReadWritePaths bind-mounts the
    # versioned dataDir, which must already exist or namespace setup fails (226/NAMESPACE).
    # create both the parent and the versioned leaf so the mount target is present.
    systemd.tmpfiles.rules = [
      "d ${siteData}/postgresql 0700 postgres postgres -"
      "d ${config.services.postgresql.dataDir} 0700 postgres postgres -"
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [5432];

    # mkDefault so a consumer redeclaring the same secret (e.g. for owner/group) wins
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
