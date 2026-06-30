{
  config,
  lib,
  modules,
  pkgs,
  siteData,
  nixosConfigurations,
  ...
}: let
  cfg = config.lab.postgres;

  # same-site postgres clients (lab.postgres.client.enable) as /32s, for pg_hba. the
  # inverse of the dbServerIp derive clients use to find this server.
  dbClientCidrs =
    (import modules.lib.site-topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }).dbClientCidrs;

  # full allow-list: derived client /32s + any explicit extras (admin VLAN, external
  # tooling -- things that aren't fleet hosts and can't be derived).
  effectiveCidrs = lib.unique (dbClientCidrs ++ cfg.extraAllowedCidrs);

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

  config = lib.mkMerge [
    # always: the readonly passwordUnits map + the admin role default. these are option
    # plumbing, not the server -- they're computed from cfg.roles regardless of where the
    # server runs (a client host can declare roles that the server-side host materializes).
    {
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
    }

    # only where this host IS the postgres server: run postgresql, create the roles/dbs,
    # the per-role password+ownership oneshots, the firewall hole, the secrets. a pure
    # client (server.enable = false) gets none of this; it points at the derived endpoint.
    (lib.mkIf cfg.server.enable {
      services.postgresql = {
        enable = true;
        package = cfg.package;
        dataDir = "${siteData}/postgresql/${cfg.package.psqlSchema}";
        enableTCPIP = true;
        settings.listen_addresses = "*";
        authentication =
          lib.optionalString (effectiveCidrs != [])
          (lib.concatMapStringsSep "\n" (cidr: "host all all ${cidr} scram-sha-256") effectiveCidrs + "\n");

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
    })
  ];
}
