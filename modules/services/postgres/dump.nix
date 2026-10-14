# local socket as postgres, so neither caller needs credentials
{
  pkgs,
  postgresPkg,
  backup,
}: ''
  set -o pipefail
  # a crashed run leaves a .partial, never let it sit where restic ships it
  rm -f ${backup.dir}/*.sql.zst.partial
  out="${backup.dir}/all-$(date -u +%Y%m%dT%H%M%SZ).sql.zst"
  ${postgresPkg}/bin/pg_dumpall -h /run/postgresql -U postgres | ${pkgs.zstd}/bin/zstd -q -o "$out.partial"
  mv "$out.partial" "$out"
  # lexical sort is chronological with this timestamp format
  ls -1 ${backup.dir}/all-*.sql.zst | head -n -${toString backup.keep} | xargs -r rm --
''
