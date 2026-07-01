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

  inherit
    ((import modules.meta.lib.site-topology {inherit lib;} {
      inherit nixosConfigurations;
      hostName = config.networking.hostName;
    }))
    dbClientCidrs
    ;

  effectiveCidrs = lib.unique (dbClientCidrs ++ cfg.extraAllowedCidrs);

  # pg 15+: public schema owner must be the role or it can't CREATE TABLE, hence ALTER SCHEMA.
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
  imports = [modules.services.postgres.options];

  config = lib.mkMerge [
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

    (lib.mkIf cfg.server.enable {
      services.postgresql = {
        enable = true;
        inherit (cfg) package;
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

      # the unit bind-mounts the versioned dataDir, which must already exist or namespace
      # setup fails (226/NAMESPACE); create both parent and leaf.
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
