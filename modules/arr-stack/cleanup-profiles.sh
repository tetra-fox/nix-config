#!/usr/bin/env bash
# delete quality profiles that recyclarr no longer manages. recyclarr creates and
# updates the profiles you declare but never deletes one (deleting a profile that
# media is assigned to is destructive, so it refuses). when you rename or drop a
# profile, the old one lingers. this reconciles that: any profile whose name isn't in
# the managed set has all its media reassigned to a default managed profile, then the
# now-empty profile is deleted.
#
# the reassignment covers everything that can hold a profile, which is the part the
# obvious "reassign movies" approach misses:
#   sonarr: series        (PUT /series/editor)
#   radarr: movies        (PUT /movie/editor)
#   radarr: collections   (PUT /collection)   <-- invisible in the movie list; a
#                                                 collection on the old profile blocks
#                                                 the delete with "still in use"
#
# fail-closed: if any reassignment for an orphan fails, that profile is NOT deleted,
# so media is never left pointing at a deleted profile.
#
# config from the environment (set by the systemd unit):
#   APP            "sonarr" | "radarr"
#   BASE_URL       arr api base, e.g. http://10.0.0.1:7878/api/v3
#   ARR_KEY_FILE   file holding the arr's api key
#   MANAGED_FILE   file holding a json array of managed profile names to keep
set -euo pipefail

arr_curl() {
  curl -s \
    --variable "apiKey@${ARR_KEY_FILE}" \
    --expand-header "X-Api-Key: {{apiKey:trim}}" \
    "$@"
}

# PUT a json body without putting it in argv (temp file + --data-binary). body stdin.
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

# orphans: profiles whose name isn't in the managed set
orphans=$(echo "$profiles" | jq -c --argjson m "$managed" '[.[] | select(.name as $n | $m | index($n) | not)]')
orphan_count=$(echo "$orphans" | jq 'length')

if [ "$orphan_count" -eq 0 ]; then
  echo "no orphaned quality profiles in ${APP}"
  exit 0
fi
echo "found ${orphan_count} orphaned quality profile(s) in ${APP}"

# default profile to reassign onto: the first managed name that exists in this arr
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

# ids of items at GET ${BASE_URL}/$1 whose qualityProfileId == $2. fails (non-zero)
# if the fetch fails, so callers can fail-closed instead of treating it as "empty".
ids_on_profile() {
  local endpoint="$1" from_id="$2" items
  items=$(arr_curl -Sf "${BASE_URL}/${endpoint}") || return 1
  echo "$items" | jq -c --argjson p "$from_id" '[.[] | select(.qualityProfileId == $p) | .id]'
}

# reassign every series/movie on $1 (orphan profile id) to the default, in bulk.
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
    jq -n --argjson ids "$ids" --argjson q "$default_id" \
      '{movieIds: $ids, qualityProfileId: $q, applyTags: "noChange"}' \
      | arr_put "${BASE_URL}/movie/editor" >/dev/null
  fi
}

# radarr only: reassign collections on $1 to the default via the collection editor.
reassign_collections() {
  local from_id="$1" ids
  ids=$(ids_on_profile "collection" "$from_id") || return 1
  [ "$(echo "$ids" | jq 'length')" -eq 0 ] && return 0
  echo "  reassigning $(echo "$ids" | jq 'length') collection(s)"
  jq -n --argjson ids "$ids" --argjson q "$default_id" \
    '{collectionIds: $ids, qualityProfileId: $q, monitored: null, monitorMovies: null, searchOnAdd: null, minimumAvailability: null}' \
    | arr_put "${BASE_URL}/collection" >/dev/null
}

echo "$orphans" | jq -c '.[]' | while IFS= read -r profile; do
  pid=$(echo "$profile" | jq -r '.id')
  pname=$(echo "$profile" | jq -r '.name')
  echo "processing orphan ${pname} (id ${pid})"

  # reassign everything off this profile; if any step fails, don't delete it (so we
  # never leave media pointing at a deleted profile). set -e turns a failed reassign
  # into a script exit, but we want to skip just this profile, so guard explicitly.
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
done

echo "${APP} orphaned-profile cleanup complete"
