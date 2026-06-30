# postgres

shared postgres with a `lab.postgres.roles` abstraction for declarative role + password + db-ownership management.

server/client split mirrors the monitoring module. the host running the db sets
`server.enable`; client hosts set `client.enable`. clients find the server via the
site-topology `dbServerIp` derive (no hardcoded address); the server admits clients via
the inverse `dbClientCidrs` derive (no hand-maintained allow-list). this makes an HA
cluster a drop-in later -- the derives swap to a VIP/leader without touching any client.

```nix
# the db server (one per site today):
{ modules, ... }: {
  imports = [modules.postgres.system];
  lab.postgres = {
    server.enable = true;
    extraAllowedCidrs = ["192.168.20.0/24"]; # non-fleet sources only (admin VLAN, tools)
    roles.myapp = {
      passwordSecret = "myapp/pg_pass";
      owns = ["myapp_db"];
    };
  };
}

# a client host (gets its IP into the server's pg_hba automatically):
{ modules, ... }: {
  imports = [modules.postgres.system];
  lab.postgres.client.enable = true;
}
```

## options (`lab.postgres.*`)

- `server.enable` - run the postgres server here. the site-topology `dbServerIp` derive
  points clients at this host's IP. without it the module only provides options (a client)
- `client.enable` - this host connects to the site's db; the server folds its hostIp into
  pg_hba via the `dbClientCidrs` derive. assumes the client reaches the db from its hostIp
  (true for direct LAN clients and netns clients SNAT'd to their hostIp)
- `package` (default `pkgs.postgresql_17`)
- `extraAllowedCidrs` - pg_hba CIDRs beyond the derived fleet clients: non-fleet sources
  like the admin VLAN or external tooling. fleet clients should set `client.enable` instead.
  localhost is added by upstream, don't list it here
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
