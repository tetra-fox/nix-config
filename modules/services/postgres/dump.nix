# the dump script shared by the single-server and HA modules: pg_dumpall (every database
# plus the globals) compressed into backup.dir, pruned to the newest `keep`. connects over
# the local socket as the postgres role, so neither module needs credentials for it.
{
  pkgs,
  postgresPkg,
  backup,
}: ''
  set -o pipefail
  # a crashed prior run can leave a partial; it must never sit where restic ships it
  rm -f ${backup.dir}/*.sql.zst.partial
  out="${backup.dir}/all-$(date -u +%Y%m%dT%H%M%SZ).sql.zst"
  ${postgresPkg}/bin/pg_dumpall -h /run/postgresql -U postgres | ${pkgs.zstd}/bin/zstd -q -o "$out.partial"
  mv "$out.partial" "$out"
  # lexical sort is chronological with this timestamp format; drop all but the newest N
  ls -1 ${backup.dir}/all-*.sql.zst | head -n -${toString backup.keep} | xargs -r rm --
''
