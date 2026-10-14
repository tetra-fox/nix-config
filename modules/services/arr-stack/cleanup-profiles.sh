#!/usr/bin/env bash
# recyclarr never deletes quality profiles, so renamed or dropped ones linger. move
# everything off each unmanaged profile onto a managed one, then delete it. a failed
# reassignment leaves the profile in place.
#
# env: APP (sonarr|radarr), BASE_URL, ARR_KEY_FILE, MANAGED_FILE (json array of names)
set -euo pipefail

arr_curl() {
  curl -s \
    --variable "apiKey@${ARR_KEY_FILE}" \
    --expand-header "X-Api-Key: {{apiKey:trim}}" \
    "$@"
}

# body on stdin, kept out of argv
arr_put() {
  local url="$1" f rc
  f=$(mktemp)
  cat > "$f"
  arr_curl -X PUT -H "Content-Type: application/json" --data-binary @"$f" -Sf "$url"
  rc=$?
  rm -f "$f"
  return $rc
}

arr_curl --retry 30 --retry-delay 2 --retry-connrefused -o /dev/null "${BASE_URL}/system/status" \
  || { echo "ERROR: arr api at ${BASE_URL} never came up" >&2; exit 1; }

managed=$(cat "$MANAGED_FILE")
profiles=$(arr_curl -Sf "${BASE_URL}/qualityprofile")

orphans=$(echo "$profiles" | jq -c --argjson m "$managed" '[.[] | select(.name as $n | $m | index($n) | not)]')
orphan_count=$(echo "$orphans" | jq 'length')

if [ "$orphan_count" -eq 0 ]; then
  echo "no orphaned quality profiles in ${APP}"
  exit 0
fi
echo "found ${orphan_count} orphaned quality profile(s) in ${APP}"

# first managed name that exists in this arr
default_id=""
default_name=""
while IFS= read -r name; do
  [ -n "$name" ] || continue
  id=$(echo "$profiles" | jq -r --arg n "$name" 'map(select(.name == $n)) | .[0].id // empty')
  if [ -n "$id" ]; then
    default_id="$id"
    default_name="$name"
    break
  fi
done < <(echo "$managed" | jq -r '.[]')

if [ -z "$default_id" ]; then
  echo "ERROR: none of the managed profiles exist in ${APP}; refusing to reassign" >&2
  exit 1
fi
echo "reassigning onto default profile ${default_name} (id ${default_id})"

# ids of items at $1 on profile $2. a failed fetch returns non-zero, not an empty list
ids_on_profile() {
  local endpoint="$1" from_id="$2" items
  items=$(arr_curl -Sf "${BASE_URL}/${endpoint}") || return 1
  echo "$items" | jq -c --argjson p "$from_id" '[.[] | select(.qualityProfileId == $p) | .id]'
}

reassign_media() {
  local from_id="$1" endpoint ids
  [ "$APP" = "sonarr" ] && endpoint="series" || endpoint="movie"
  ids=$(ids_on_profile "$endpoint" "$from_id") || return 1
  [ "$(echo "$ids" | jq 'length')" -eq 0 ] && return 0
  echo "  reassigning $(echo "$ids" | jq 'length') ${endpoint}(s)"
  if [ "$APP" = "sonarr" ]; then
    jq -n --argjson ids "$ids" --argjson q "$default_id" \
      '{seriesIds: $ids, qualityProfileId: $q}' \
      | arr_put "${BASE_URL}/series/editor" >/dev/null
  else
    # no applyTags: "noChange" is rejected with a 400, omitting it leaves tags alone
    jq -n --argjson ids "$ids" --argjson q "$default_id" \
      '{movieIds: $ids, qualityProfileId: $q}' \
      | arr_put "${BASE_URL}/movie/editor" >/dev/null
  fi
}

# radarr collections aren't in the movie list but still block the delete as "still in use"
reassign_collections() {
  local from_id="$1" ids
  ids=$(ids_on_profile "collection" "$from_id") || return 1
  [ "$(echo "$ids" | jq 'length')" -eq 0 ] && return 0
  echo "  reassigning $(echo "$ids" | jq 'length') collection(s)"
  jq -n --argjson ids "$ids" --argjson q "$default_id" \
    '{collectionIds: $ids, qualityProfileId: $q, monitored: null, monitorMovies: null, searchOnAdd: null, minimumAvailability: null}' \
    | arr_put "${BASE_URL}/collection" >/dev/null
}

while IFS= read -r profile; do
  pid=$(echo "$profile" | jq -r '.id')
  pname=$(echo "$profile" | jq -r '.name')
  echo "processing orphan ${pname} (id ${pid})"

  if ! reassign_media "$pid"; then
    echo "  WARNING: media reassignment failed for ${pname}; leaving profile in place" >&2
    continue
  fi
  if [ "$APP" = "radarr" ]; then
    if ! reassign_collections "$pid"; then
      echo "  WARNING: collection reassignment failed for ${pname}; leaving profile in place" >&2
      continue
    fi
  fi

  if arr_curl -X DELETE -Sf "${BASE_URL}/qualityprofile/${pid}" >/dev/null; then
    echo "  deleted ${pname}"
  else
    echo "  WARNING: delete failed for ${pname} (still in use?); left in place" >&2
  fi
done < <(echo "$orphans" | jq -c '.[]')

echo "${APP} orphaned-profile cleanup complete"
