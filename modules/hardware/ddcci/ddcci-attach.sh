#!/usr/bin/env bash
# a DDC/CI write to the valve index's DP bus wedges it, and its i2c ignores the
# seek so a single EDID read can pass by luck. a bus must pass twice before any write
edid_header="0x00 0xff 0xff 0xff 0xff 0xff 0xff 0x00"

# 128 bytes at 0x50, fixed 8-byte header, block sums to 0 mod 256
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
  # an adapter unplugged mid-loop reads empty
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
