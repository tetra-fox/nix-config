# postgres

shared postgres with a `lab.postgres.roles` abstraction for declarative role + password + db-ownership management.

```nix
{ modules, ... }: {
  imports = [modules.postgres.system];

  lab.postgres = {
    allowedCidrs = ["172.16.0.0/12"];
    roles.myapp = {
      passwordSecret = "myapp/pg_pass";
      owns = ["myapp_db"];
    };
  };

  systemd.services.myapp-thing = {
    requires = [config.lab.postgres.passwordUnits.myapp];
    after    = [config.lab.postgres.passwordUnits.myapp];
  };
}
```

## options (`lab.postgres.*`)

- `package` (default `pkgs.postgresql_17`)
- `allowedCidrs` - extra pg_hba CIDRs with scram-sha-256. localhost is added by upstream, don't list it here
- `openFirewall` - 5432/tcp on the host firewall
- `passwordUnits` (read-only) - `role -> generated unit name`. use this in `requires`/`after` so consumers don't hardcode unit names
- `admin.enable` - shorthand for an `admin` superuser role (superuser, createdb, createrole, replication)
- `admin.passwordSecret` (default `"postgres/admin_pass"`)
- `roles.<name>.passwordSecret` - sops path
- `roles.<name>.clauses` - forwarded to `ensureUsers[].ensureClauses`
- `roles.<name>.owns` - dbs this role owns; auto-added to `ensureDatabases`

## gotchas

- pg 15+ tightened the public schema. `GRANT ALL ON DATABASE` is no longer enough to `CREATE TABLE` in `public`; the schema's owner has to be the role that wants to create. the per-role oneshot also runs `ALTER SCHEMA public OWNER TO <role>` for every db in `owns`
- password-set oneshots depend on `postgresql-setup.service` (the unit that runs `ensureUsers`), not `postgresql.service` itself. otherwise the `ALTER USER` races against the `CREATE ROLE`
- `passwordUnits` exists so consumers reference `config.lab.postgres.passwordUnits.<role>` instead of typing `"postgresql-set-foo-password.service"` literally
