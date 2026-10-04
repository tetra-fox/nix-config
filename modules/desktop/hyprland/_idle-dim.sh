#!/usr/bin/env bash
# dim each backlight (the ddcci monitors, see modules/hardware/ddcci) to a
# percent of its current level, and put the saved levels back on restore.
# hypridle spawns dim and restore independently, so a resume that lands while a
# dim is still writing waits on the lock instead of restoring first
state="$XDG_RUNTIME_DIR/idle-dim"
exec 9>"$state.lock"
flock 9

shopt -s nullglob
pids=()
case "${1-}" in
dim)
  percent=$2
  : >"$state"
  for dev in /sys/class/backlight/*; do
    name=${dev##*/}
    level=$(<"$dev/brightness")
    echo "$name $level" >>"$state"
    brightnessctl -q -d "$name" set $((level * percent / 100)) &
    pids+=($!)
  done
  ;;
restore)
  while read -r name level; do
    brightnessctl -q -d "$name" set "$level" &
    pids+=($!)
  done <"$state"
  rm "$state"
  ;;
*)
  echo "usage: idle-dim dim PERCENT | idle-dim restore" >&2
  exit 2
  ;;
esac

# each monitor is on its own i2c bus, so the writes run in parallel
for pid in "${pids[@]}"; do wait "$pid"; done
