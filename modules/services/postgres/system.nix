{
  config,
  lib,
  modules,
  pkgs,
  topo,
  ...
}: let
  siteData = config.lab.site.dataDir;
  cfg = config.lab.postgres;

  inherit (topo) dbClientCidrs;

  effectiveCidrs = lib.unique (dbClientCidrs ++ cfg.extraAllowedCidrs);

  # the role SQL is shared with the HA module (role-sql.nix); idempotent, so running it
  # after ensureUsers has already created the role is fine
  roleSql = import modules.services.postgres.role-sql {inherit lib;};

  # the dump script is shared with the HA module too (dump.nix); there it runs leader-gated
  dumpScript = import modules.services.postgres.dump {
    inherit pkgs;
    postgresPkg = cfg.package;
    inherit (cfg) backup;
  };

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
    script = ''
      ${cfg.package}/bin/psql -v "pass=$(cat $CREDENTIALS_DIRECTORY/pgpass)" <<EOF
      ${roleSql {
        inherit name role;
        passwordVar = "pass";
      }}
      EOF
    '';
  };
in {
  imports = [modules.services.postgres.options];

  config = lib.mkMerge [
    {
      lab.postgres.passwordUnits = lib.mapAttrs (name: _: "postgresql-set-${name}-password.service") cfg.roles;
    }

    (lib.mkIf cfg.server.enable {
      # nix-topology's postgresql extractor prints 0.0.0.0 whenever enableTCPIP is set
      # (it never reads listen_addresses); mkForce replaces its line with the real listeners
      topology.self.services.postgresql.details.listen.text =
        lib.mkForce "${config.services.postgresql.settings.listen_addresses}:${toString config.services.postgresql.settings.port}";

      services.postgresql = {
        enable = true;
        inherit (cfg) package;
        dataDir = "${siteData}/postgresql/${cfg.package.psqlSchema}";
        enableTCPIP = true;
        # mkForce: enableTCPIP hard-sets the wildcard upstream. fleet clients hit the
        # east-west address, admin psql the server-VLAN one; nothing needs a wildcard
        settings.listen_addresses = lib.mkForce (lib.concatStringsSep ", " (lib.unique (
          ["127.0.0.1"]
          ++ lib.filter (a: a != null) [config.lab.site.internalIp config.lab.site.hostIp]
        )));
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

    (lib.mkIf (cfg.server.enable && cfg.backup.enable) {
      systemd = {
        services.postgres-dump = {
          description = "pg_dumpall to ${cfg.backup.dir} (keep newest ${toString cfg.backup.keep})";
          after = ["postgresql.service"];
          requires = ["postgresql.service"];
          unitConfig.RequiresMountsFor = [cfg.backup.dir];
          serviceConfig = {
            Type = "oneshot";
            User = "postgres";
            # a wedged write (e.g. an unreachable NFS dir) should fail the unit, and with
            # it the fleet failed-unit alert, instead of hanging the oneshot forever
            TimeoutStartSec = "15min";
          };
          script = dumpScript;
        };

        timers.postgres-dump = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = cfg.backup.onCalendar;
            Persistent = true;
          };
        };

        tmpfiles.rules = ["d ${cfg.backup.dir} 0700 postgres postgres -"];
      };
    })
  ];
}
