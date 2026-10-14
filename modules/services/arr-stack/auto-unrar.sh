# qbittorrent AutoRun hook: auto-unrar "%R"
# output lands in qbittorrent's journal, <N> prefixes are journald priorities
log()     { printf '<6>[auto-unrar] %s\n' "$*" >&2; }
log_err() { printf '<3>[auto-unrar] %s\n' "$*" >&2; }

[[ $# -ge 1 ]] || { log_err "no torrent path argument (expected qbittorrent %R)"; exit 1; }
root="$1"
[[ -d "$root" ]] || { log_err "'$root' is not a directory"; exit 1; }

fail=0

# temp file instead of process substitution so find's exit status is checkable
rars=$(mktemp)
trap 'rm -f "$rars"' EXIT

scan() {
  if ! find "$root" -type f \( \
      -name "*.part1.rar"   -o \
      -name "*.part01.rar"  -o \
      -name "*.part001.rar" -o \
      \( -name "*.rar" ! -name "*.part*.rar" \) \
  \) -print0 >"$rars"; then
    log_err "find failed scanning $root, extracting what it did report"
    fail=1
  fi
}

# -o+ re-extracts and reports success every time, so without this every torrent
# would run to the pass cap
declare -A seen=()

# returns 0 if this pass extracted something new
extract_pass() {
  local new=0 rar dest rc
  while IFS= read -r -d '' rar; do
    [[ -n "${seen[$rar]:-}" ]] && continue
    seen[$rar]=1
    # kept apart from the seeded rar parts, same filesystem so arr hardlinks work
    dest="$(dirname "$rar")/_extracted/"
    log "extracting: $(basename "$rar")"
    # -ai: ignore stored perms so output honors the 0002 umask for media-group imports
    # -p-: fail fast on encrypted archives instead of reading stdin for a password
    rc=0
    unrar x -o+ -ai -p- -idq "$rar" "$dest" >&2 || rc=$?
    # exit 1 is a warning (e.g. unsafe symlink member refused, CVE-2022-30333)
    if [[ "$rc" -le 1 ]]; then
      log "ok"
      new=1
    else
      log_err "failed ($rc): $rar"
      fail=1
    fi
  done <"$rars"
  [[ "$new" -eq 1 ]]
}

# rescan for nested rars until a pass finds nothing new, capped against crafted nesting
done_clean=0
for ((pass = 1; pass <= 8; pass++)); do
  scan
  if ! extract_pass; then
    done_clean=1
    break
  fi
done
[[ "$done_clean" -eq 1 ]] || { log_err "hit pass cap (8) for $root, deep nesting left unextracted"; fail=1; }

log "done: $root"
exit "$fail"
