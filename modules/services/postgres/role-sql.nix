# idempotent: CREATE ROLE/DATABASE have no IF NOT EXISTS, so creates go through \gexec.
# callers fill passwordVar with \getenv, not psql -v, since argv is world-readable in /proc
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

  # pg 15+: without owning public the role can't CREATE TABLE
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
