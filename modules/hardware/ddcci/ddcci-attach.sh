#!/usr/bin/env bash
# bind ddcci-backlight to each nvidia i2c bus that holds a real EDID at 0x50.
# never write to a bus that isn't a monitor: a DDC/CI write to the valve index's
# DP port wedges it. the index's i2c ignores the seek and can pass a check by
# luck on a single read, so a bus must pass the full EDID check twice before it
# sees a 0x37 write.
edid_header="0x00 0xff 0xff 0xff 0xff 0xff 0xff 0x00"

# a real EDID is 128 bytes at 0x50: fixed 8-byte header, block sums to 0 mod 256
edid_ok() {
  local raw bytes sum=0 b
  raw=$(timeout 5 i2ctransfer -y "$1" w1@0x50 0x00 r128 2>/dev/null) || return 1
  case "$raw" in "$edid_header"*) ;; *) return 1 ;; esac
  read -ra bytes <<<"$raw"
  [ "${#bytes[@]}" -eq 128 ] || return 1
  for b in "${bytes[@]}"; do sum=$((sum + b)); done
  ((sum % 256 == 0))
}

shopt -s nullglob
for dev in /sys/class/i2c-dev/i2c-*; do
  # name read can race an unplug; a vanished adapter reads empty and is skipped
  case "$(cat "$dev/name" 2>/dev/null || true)" in "NVIDIA i2c adapter"*) ;; *) continue ;; esac
  bus=$(basename "$dev")
  n=${bus#i2c-}
  backlight="/sys/class/backlight/ddcci$n"
  stub="/sys/bus/i2c/devices/$n-0037"
  if [ -e "$backlight" ]; then continue; fi

  if ! edid_ok "$n" || ! edid_ok "$n"; then
    echo "$bus: no valid edid, skipped"
    continue
  fi

  # delete the stub a failed probe leaves, else the next write hits EBUSY
  for _ in 1 2 3; do
    if [ -e "$stub" ]; then
      echo 0x37 > "/sys/bus/i2c/devices/$bus/delete_device" 2>/dev/null || true
    fi
    echo "ddcci 0x37" > "/sys/bus/i2c/devices/$bus/new_device" 2>/dev/null || true
    if [ -e "$backlight" ]; then break; fi
    sleep 1
  done

  if [ -e "$backlight" ]; then
    echo "$bus: bound ddcci$n"
  else
    echo "$bus: valid edid but ddcci bind failed" >&2
    if [ -e "$stub" ]; then
      echo 0x37 > "/sys/bus/i2c/devices/$bus/delete_device" 2>/dev/null || true
    fi
  fi
done
