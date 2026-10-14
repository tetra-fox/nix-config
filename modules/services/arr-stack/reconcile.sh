#!/usr/bin/env bash
# reconcile an arr provider resource (download clients, notifications) against a
# declared set: prune undeclared items, then create-or-update the rest from the schema.
#
# env: BASE_URL, RESOURCE (e.g. downloadclient), SCHEMA_KEY (schema field matched by
# schemaName), LABEL (for logs), ARR_KEY_FILE, ITEMS_FILE
#
# ITEMS_FILE is a json array of
#   {name, schemaName, top?, fields?, secretField?, secretFile?}
# top overrides top-level fields, fields overrides .fields[].value, secretField is set
# from secretFile. secrets are read from files so they stay out of argv
set -euo pipefail

arr_curl() {
  curl -s \
    --variable "apiKey@${ARR_KEY_FILE}" \
    --expand-header "X-Api-Key: {{apiKey:trim}}" \
    "$@"
}

# $1 method, $2 url, body on stdin, kept out of argv
arr_send() {
  local method="$1" url="$2" f rc
  f=$(mktemp)
  cat > "$f"
  arr_curl -X "$method" -H "Content-Type: application/json" --data-binary @"$f" -Sf "$url"
  rc=$?
  rm -f "$f"
  return $rc
}

# unit ordering only guarantees the process launched
arr_curl --retry 30 --retry-delay 2 --retry-connrefused -o /dev/null "${BASE_URL}/system/status" \
  || { echo "ERROR: arr api at ${BASE_URL} never came up" >&2; exit 1; }

SCHEMAS=$(arr_curl -Sf "${BASE_URL}/${RESOURCE}/schema")
LIVE=$(arr_curl -Sf "${BASE_URL}/${RESOURCE}")

# a failed prune is only a warning
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

# $2 is the live item or a schema template
build_body() {
  local item="$1" base="$2"
  local name top fields secret_field secret_file
  name=$(echo "$item" | jq -r '.name')
  top=$(echo "$item" | jq -c '.top // {}')
  fields=$(echo "$item" | jq -c '.fields // {}')
  secret_field=$(echo "$item" | jq -r '.secretField // empty')
  secret_file=$(echo "$item" | jq -r '.secretFile // empty')

  # schema templates have an empty name, which the arr rejects with a 400
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

# process substitution, not a pipe, so `exit 1` fails the unit instead of a subshell
while IFS= read -r item; do
  name=$(echo "$item" | jq -r '.name')
  schema_name=$(echo "$item" | jq -r '.schemaName')
  echo "reconciling ${LABEL} ${name}"

  existing=$(echo "$LIVE" | jq -c --arg n "$name" '.[] | select(.name == $n)' || true)
  if [ -n "$existing" ]; then
    id=$(echo "$existing" | jq -r '.id')
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
