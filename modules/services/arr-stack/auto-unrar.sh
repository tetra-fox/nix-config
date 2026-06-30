# qBittorrent post-download auto-unrar.
# usage: auto-unrar "%R" (qbittorrent's Root path of torrent token)
#
# runs as a detached AutoRun child that inherits qbittorrent-nox's stdout/stderr,
# which the unit sends to the journal. the <N> prefixes are journald priorities
# (<6> info, <3> err) so `journalctl -u qbittorrent -p err` surfaces failures.
# read everything with: journalctl -u qbittorrent | grep auto-unrar
log()     { printf '<6>[auto-unrar] %s\n' "$*" >&2; }
log_err() { printf '<3>[auto-unrar] %s\n' "$*" >&2; }

# gate on $# first: under set -u (writeShellApplication adds it) reading $1 with
# no args aborts with a raw "unbound variable" before our own error can log
[[ $# -ge 1 ]] || { log_err "no torrent path argument (expected qbittorrent %R)"; exit 1; }
root="$1"
[[ -d "$root" ]] || { log_err "'$root' is not a directory"; exit 1; }

fail=0

# find runs in a process substitution when read directly, so its exit status is
# invisible and a partial scan (i/o error, a path vanishing mid-walk) would log a
# false success. collect to a temp file so we can check find's status. -print0
# keeps untrusted filenames with newlines/spaces intact
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

# track extracted archives so an outer set isn't re-extracted every pass (-o+
# re-extracts and reports success unconditionally, which would otherwise run to
# the pass cap on every ordinary torrent)
declare -A seen=()

# returns 0 if this pass extracted something new, 1 otherwise
extract_pass() {
  local new=0 rar dest rc
  while IFS= read -r -d '' rar; do
    [[ -n "${seen[$rar]:-}" ]] && continue
    seen[$rar]=1
    # extract into a sibling _extracted/ next to the archive rather than in place,
    # so the unpacked media is separate from the rar parts qbittorrent seeds. same
    # filesystem as the torrent, so the *arr hardlink import still works
    dest="$(dirname "$rar")/_extracted/"
    log "extracting: $(basename "$rar")"
    # -ai ignores the archive's stored unix perms so output honors the service
    #    umask (0002) and stays group-writable; without it unrar stamps the
    #    stored perms verbatim (commonly 0644, or 0600 from hostile archives)
    #    and breaks media-group imports
    # -p- never prompts for a password, so an encrypted archive from an
    #    untrusted torrent fails fast with a clear cause instead of an opaque
    #    stdin read error
    # -o+ overwrites, -idq drops the progress spam from the journal
    rc=0
    unrar x -o+ -ai -p- -idq "$rar" "$dest" >&2 || rc=$?
    # unrar exit 1 is a non-fatal warning (e.g. it refused an unsafe symlink
    # member per its CVE-2022-30333 default) while still extracting the real
    # media, so treat <=1 as success and only fail on >=2
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

# rescan after each pass so archives unpacked from an outer set (nested rars in
# repacked/scene packs) get picked up. stop when a pass extracts nothing new. cap
# iterations so a crafted nesting chain cannot loop forever
done_clean=0
for ((pass = 1; pass <= 8; pass++)); do
  scan
  if ! extract_pass; then
    done_clean=1
    break
  fi
done
# if the last allowed pass still found new archives we stopped at the cap with
# work likely left, not because nesting was exhausted
[[ "$done_clean" -eq 1 ]] || { log_err "hit pass cap (8) for $root, deep nesting left unextracted"; fail=1; }

log "done: $root"
exit "$fail"
