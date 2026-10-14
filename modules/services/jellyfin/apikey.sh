#!/usr/bin/env bash
# upsert an ApiKeys row whose AccessToken is our secret. jellyfin compares tokens
# verbatim and re-reads ApiKeys per request, so this works while it runs.
# env: JELLYFIN_DB, KEY_NAME, KEY_FILE. readfile() keeps the token out of argv
set -euo pipefail

# on first run the db file appears before the migration that creates ApiKeys
for _ in $(seq 1 60); do
  [ -f "$JELLYFIN_DB" ] \
    && sqlite3 "$JELLYFIN_DB" "SELECT 1 FROM ApiKeys LIMIT 1;" >/dev/null 2>&1 \
    && break
  sleep 2
done
if ! sqlite3 "$JELLYFIN_DB" "SELECT 1 FROM ApiKeys LIMIT 1;" >/dev/null 2>&1; then
  echo "ERROR: ${JELLYFIN_DB} ApiKeys table never appeared (jellyfin first-run migration?)" >&2
  exit 1
fi

# .timeout waits out jellyfin's writer
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
