#!/usr/bin/env bash
# reconcile an arr "provider" resource (download clients, notifications, ...) against
# a declared set, via the arr rest api. these resources are db rows, not config, so
# this is how we configure them declaratively: prune anything not declared, then
# create-or-update each declared item from its schema.
#
# config comes from the environment (set by the systemd unit):
#   BASE_URL      arr api base, e.g. http://10.0.0.1:8989/api/v3
#   RESOURCE      path segment under BASE_URL, e.g. downloadclient / notification
#   SCHEMA_KEY    schema array field identifying a template:
#                 implementationName (download clients) / implementation (notifications)
#   LABEL         human label for log lines, e.g. "download client"
#   ARR_KEY_FILE  file holding the arr's own api key (authenticates us to the arr)
#   ITEMS_FILE    file holding the declared items as a json array (see below)
#
# each item in ITEMS_FILE:
#   {
#     "name": "Jellyfin",            # unique name; prune key
#     "schemaName": "MediaBrowser",  # matches schema[].<SCHEMA_KEY>
#     "top":    { "onUpgrade": true },        # top-level field overrides (optional)
#     "fields": { "host": "x", "port": 8096 },# .fields[].value overrides (optional)
#     "secretField": "apiKey",       # optional: set one .fields[] entry from a file
#     "secretFile": "/run/credentials/.../key"
#   }
#
# the api key is passed to curl via --variable + --expand-header, read from a file, so
# it never lands in argv (visible in ps/proc). secretField values are read at runtime
# with jq --rawfile for the same reason. nothing secret is baked into the script.
set -euo pipefail

# curl against the arr with the api key supplied from ARR_KEY_FILE via curl variable.
# extra args passed through; on stdin-data calls the caller sets $BODY.
arr_curl() {
  curl -s \
    --variable "apiKey@${ARR_KEY_FILE}" \
    --expand-header "X-Api-Key: {{apiKey:trim}}" \
    "$@"
}

# POST/PUT a json body without putting it in argv: write to a temp file, send with
# --data-binary @file, remove it after. $1 is the method, $2 the url, body on stdin.
arr_send() {
  local method="$1" url="$2" f rc
  f=$(mktemp)
  cat > "$f"
  arr_curl -X "$method" -H "Content-Type: application/json" --data-binary @"$f" -Sf "$url"
  rc=$?
  rm -f "$f"
  return $rc
}

# wait for the api to answer; unit ordering only guarantees the process launched.
arr_curl --retry 30 --retry-delay 2 --retry-connrefused -o /dev/null "${BASE_URL}/system/status" \
  || { echo "ERROR: arr api at ${BASE_URL} never came up" >&2; exit 1; }

SCHEMAS=$(arr_curl -Sf "${BASE_URL}/${RESOURCE}/schema")
LIVE=$(arr_curl -Sf "${BASE_URL}/${RESOURCE}")

# prune any live item whose name isn't in the declared set. a failed delete is a
# non-fatal warning (pruning is cleanup, not the core job). process substitution keeps
# the loop in this shell, consistent with the create/update loop below.
declared_names=$(jq '[.[].name]' "$ITEMS_FILE")
while IFS= read -r live_item; do
  name=$(echo "$live_item" | jq -r '.name')
  id=$(echo "$live_item" | jq -r '.id')
  if ! echo "$declared_names" | jq -e --arg n "$name" 'index($n)' >/dev/null; then
    echo "pruning undeclared ${LABEL} ${name} (id ${id})"
    arr_curl -X DELETE -Sf "${BASE_URL}/${RESOURCE}/${id}" >/dev/null \
      || echo "  warning: failed to delete ${name}"
  fi
done < <(echo "$LIVE" | jq -c '.[]')

# build the request body for one declared item, starting from `base` (either the
# existing live item or a fresh schema template): apply top-level overrides, then
# per-field value overrides, then the optional secret field read from its file.
build_body() {
  local item="$1" base="$2"
  local name top fields secret_field secret_file
  name=$(echo "$item" | jq -r '.name')
  top=$(echo "$item" | jq -c '.top // {}')
  fields=$(echo "$item" | jq -c '.fields // {}')
  secret_field=$(echo "$item" | jq -r '.secretField // empty')
  secret_file=$(echo "$item" | jq -r '.secretFile // empty')

  # the create base is the /schema template whose top-level name is empty, and the
  # arr rejects an empty name with a 400 -- so .name MUST be set explicitly. (it's not
  # in .top because the prune/match logic keys on it; carrying it separately keeps that
  # one source.) on update this just re-sets the same name, which is harmless.
  if [ -n "$secret_field" ]; then
    echo "$base" | jq \
      --arg name "$name" --argjson top "$top" --argjson f "$fields" \
      --arg sf "$secret_field" --rawfile sv "$secret_file" '
        .name = $name
        | reduce ($top | keys[]) as $k (.; .[$k] = $top[$k])
        | .fields |= map(if $f[.name] != null then .value = $f[.name] else . end)
        | .fields |= map(if .name == $sf then .value = ($sv | sub("\n+$"; "")) else . end)
      '
  else
    echo "$base" | jq \
      --arg name "$name" --argjson top "$top" --argjson f "$fields" '
        .name = $name
        | reduce ($top | keys[]) as $k (.; .[$k] = $top[$k])
        | .fields |= map(if $f[.name] != null then .value = $f[.name] else . end)
      '
  fi
}

# create-or-update each declared item. read via process substitution (not a pipe) so
# the loop runs in this shell -- a failed create/update can `exit 1` the whole script
# and fail the unit, instead of dying silently in a pipe subshell.
while IFS= read -r item; do
  name=$(echo "$item" | jq -r '.name')
  schema_name=$(echo "$item" | jq -r '.schemaName')
  echo "reconciling ${LABEL} ${name}"

  existing=$(echo "$LIVE" | jq -c --arg n "$name" '.[] | select(.name == $n)' || true)
  if [ -n "$existing" ]; then
    id=$(echo "$existing" | jq -r '.id')
    # build_body | arr_send in a pipe would mask arr_send's exit status, so stage the
    # body in a var and check the send result -- a 4xx (curl -Sf) must fail the unit,
    # not silently log success.
    body=$(build_body "$item" "$existing")
    if printf '%s' "$body" | arr_send PUT "${BASE_URL}/${RESOURCE}/${id}" >/dev/null; then
      echo "  updated ${name} (id ${id})"
    else
      echo "  ERROR: failed to update ${name} (id ${id})" >&2
      exit 1
    fi
  else
    schema=$(echo "$SCHEMAS" | jq -c --arg i "$schema_name" --arg key "$SCHEMA_KEY" '.[] | select(.[$key] == $i)')
    if [ -z "$schema" ]; then
      echo "  ERROR: no schema for ${schema_name}" >&2
      exit 1
    fi
    body=$(build_body "$item" "$schema")
    if printf '%s' "$body" | arr_send POST "${BASE_URL}/${RESOURCE}" >/dev/null; then
      echo "  created ${name}"
    else
      echo "  ERROR: failed to create ${name}" >&2
      exit 1
    fi
  fi
done < <(jq -c '.[]' "$ITEMS_FILE")

echo "${LABEL}s reconciled"
