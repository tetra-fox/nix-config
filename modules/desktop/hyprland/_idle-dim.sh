#!/usr/bin/env bash
# dim each backlight (the ddcci monitors, see modules/hardware/ddcci) to a
# percent of its current level, and put the saved levels back on restore.
# hypridle spawns dim and restore independently, so a resume that lands while a
# dim is still writing waits on the lock instead of restoring first
state="$XDG_RUNTIME_DIR/idle-dim"
exec 9>"$state.lock"
flock 9

# each monitor is on its own i2c bus, so the writes run in parallel
pids=()
wait_all() {
  for pid in "${pids[@]}"; do wait "$pid"; done
}

shopt -s nullglob
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
  wait_all
  ;;
restore)
  # the blank step restores ahead of dpms off, so on wake there's nothing left
  [ -e "$state" ] || exit 0
  while read -r name level; do
    brightnessctl -q -d "$name" set "$level" &
    pids+=($!)
  done <"$state"
  # a failed write exits in wait_all, keeping the levels for the next restore
  wait_all
  rm "$state"
  ;;
*)
  echo "usage: idle-dim dim PERCENT | idle-dim restore" >&2
  exit 2
  ;;
esac
