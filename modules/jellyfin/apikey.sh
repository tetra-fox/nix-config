#!/usr/bin/env bash
# ensure a row exists in jellyfin's ApiKeys table whose AccessToken equals our
# shared secret, so the arrs (and anything else) can authenticate to jellyfin with a
# value we control. jellyfin compares the token verbatim (no hashing), so an injected
# value works like a dashboard-generated one. the db is WAL mode and jellyfin re-reads
# ApiKeys per request, so an upsert while jellyfin runs takes effect on the next call.
#
# config from the environment (set by the systemd unit):
#   JELLYFIN_DB    path to jellyfin.db
#   KEY_NAME       ApiKeys.Name to upsert (e.g. "arr")
#   KEY_FILE       file holding the token (a sops secret via LoadCredential)
#
# the token is read straight from KEY_FILE inside sqlite with readfile() so it never
# lands in argv; rtrim drops the trailing newline sops adds.
set -euo pipefail

# wait for jellyfin to have created the db at least once
for _ in $(seq 1 30); do
  [ -f "$JELLYFIN_DB" ] && break
  sleep 1
done
if [ ! -f "$JELLYFIN_DB" ]; then
  echo "ERROR: ${JELLYFIN_DB} never appeared" >&2
  exit 1
fi

# insert the row if absent, else overwrite its token. .timeout waits out jellyfin's
# WAL writer if it's mid-write.
sqlite3 "$JELLYFIN_DB" <<SQL >/dev/null
.timeout 5000
INSERT INTO ApiKeys (DateCreated, DateLastActivity, Name, AccessToken)
  SELECT datetime('now'), datetime('now'), '${KEY_NAME}',
         rtrim(readfile('${KEY_FILE}'), char(10)||char(13))
  WHERE NOT EXISTS (SELECT 1 FROM ApiKeys WHERE Name = '${KEY_NAME}');
UPDATE ApiKeys
  SET AccessToken = rtrim(readfile('${KEY_FILE}'), char(10)||char(13))
  WHERE Name = '${KEY_NAME}';
SQL

echo "jellyfin api key row '${KEY_NAME}' reconciled"
