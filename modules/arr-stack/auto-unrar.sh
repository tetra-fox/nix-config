# qBittorrent post-download auto-unrar.
# usage: auto-unrar "%R" (qbittorrent's Root path of torrent token)

LOG="/tmp/auto_unrar.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

[[ -d "$1" ]] || { log "ERROR: '$1' is not a directory"; exit 1; }

fail=0
while IFS= read -r -d '' rar; do
  log "Extracting: $(basename "$rar")"
  if unrar x -o+ "$rar" "$(dirname "$rar")/" >> "$LOG" 2>&1; then
    log "OK"
  else
    log "FAILED: $rar"
    fail=1
  fi
done < <(find "$1" -type f \( \
    -name "*.part1.rar"   -o \
    -name "*.part01.rar"  -o \
    -name "*.part001.rar" -o \
    \( -name "*.rar" ! -name "*.part*.rar" \) \
\) -print0)

log "Done: $1"
exit "$fail"
