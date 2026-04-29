# postgres

shared postgres instance

wraps `services.postgresql` with a `lab.postgres.roles` abstraction for declarative role + password + db-ownership management

## usage

```nix
{ modules, ... }: {
  imports = [modules.postgres.system];

  lab.postgres = {
    allowedCidrs = ["172.16.0.0/12"];          # extra pg_hba CIDRs
    roles.myapp = {
      passwordSecret = "myapp/pg_pass";        # sops path
      owns = ["myapp_db"];                     # gets db owner + schema owner
    };
  };

  systemd.services.myapp-thing = {
    requires = [config.lab.postgres.passwordUnits.myapp];
    after    = [config.lab.postgres.passwordUnits.myapp];
  };
}
```

## options (`lab.postgres.*`)

| option | type | default | description |
|---|---|---|---|
| `package` | package | `pkgs.postgresql_17` | postgres package |
| `allowedCidrs` | `listOf str` | `[]` | CIDRs added to pg_hba.conf with scram-sha-256. localhost is added by upstream and shouldn't appear here |
| `openFirewall` | bool | `false` | open 5432/tcp in the host firewall |
| `passwordUnits` | `attrsOf str` | (read-only) | role name -> generated systemd unit name. use this in `requires`/`after` so consumers don't hardcode unit name strings |
| `admin.enable` | bool | `false` | shorthand for declaring an `admin` superuser role (clauses: superuser, createdb, createrole, replication) |
| `admin.passwordSecret` | str | `"postgres/admin_pass"` | sops path for the admin role's password |
| `roles.<name>.passwordSecret` | str | (required) | sops path holding this role's password |
| `roles.<name>.clauses` | `attrsOf bool` | `{}` | forwarded to `services.postgresql.ensureUsers[].ensureClauses` |
| `roles.<name>.owns` | `listOf str` | `[]` | dbs this role should own; auto-added to `services.postgresql.ensureDatabases` |

## provides

- `services.postgresql` (daemon, dataDir under `siteData/postgresql/<version>`, listen on `*`)
- pg_hba.conf entries for each CIDR in `allowedCidrs`, scram-sha-256 auth
- one `services.postgresql.ensureUsers` entry per role (with the role's `clauses`)
- auto-derived `services.postgresql.ensureDatabases` from every role's `owns` list
- a `sops.secrets.<role.passwordSecret>` declaration per role (`mkDefault` so consumers can override owner/group)
- a `postgresql-set-<name>-password.service` oneshot per role that on every boot runs `ALTER USER <name> WITH ENCRYPTED PASSWORD :'pass'` plus, for each db in `owns`, `ALTER DATABASE ... OWNER TO <name>` and `ALTER SCHEMA public OWNER TO <name>`

## expects

- which roles exist (declare them in `lab.postgres.roles`)
- LAN-facing access: open the firewall (`openFirewall = true`) and add LAN CIDRs to `allowedCidrs`
- any consumer's `requires`/`after` wiring on the password-set units

## design notes

- pg 15+ tightened the public schema; `GRANT ALL ON DATABASE` is no longer enough to `CREATE TABLE` in `public` - the schema's owner has to be the role that wants to create. ownership transfer is bundled into the same oneshot
- password-set units depend on `postgresql-setup.service` (the unit that actually runs `ensureUsers`), not `postgresql.service` itself. otherwise the ALTER USER races against the CREATE ROLE
- `passwordUnits` exists to avoid stringly-typed coupling; consumers reference `config.lab.postgres.passwordUnits.<role>` so a role rename propagates to all dependents
