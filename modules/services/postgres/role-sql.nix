# the reconcile SQL a postgres role needs, shared by the single-server module (per-role
# oneshot after ensureUsers) and the HA module (leader-gated reconcile, no upstream module
# to lean on). idempotent: CREATE ... IF NOT EXISTS isn't valid SQL, so the creates are
# guarded with SELECT ... \gexec and everything else is ALTER.
# pg 15+: the public schema owner must be the role or it can't CREATE TABLE, hence the
# ALTER SCHEMA per owned db.
# passwordVar is the psql -v variable holding the password, so it never hits argv.
{lib}: {
  name,
  role,
  passwordVar,
}: let
  clauseStr =
    lib.concatStringsSep " "
    (lib.mapAttrsToList (c: v: lib.optionalString v (lib.toUpper c))
      (lib.filterAttrs (_: v: v) role.clauses));

  mkDb = db: ''
    SELECT 'CREATE DATABASE "${db}" OWNER ${name}'
      WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db}')\gexec
    ALTER DATABASE "${db}" OWNER TO ${name};
  '';

  mkSchema = db: ''
    \connect "${db}"
    ALTER SCHEMA public OWNER TO ${name};
    \connect postgres
  '';
in
  lib.concatStringsSep "\n" (
    [
      ''
        SELECT 'CREATE ROLE ${name} LOGIN ${clauseStr}'
          WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${name}')\gexec
        ALTER ROLE ${name} WITH LOGIN ${clauseStr} ENCRYPTED PASSWORD :'${passwordVar}';
      ''
    ]
    ++ map mkDb role.owns
    ++ map mkSchema role.owns
  )
