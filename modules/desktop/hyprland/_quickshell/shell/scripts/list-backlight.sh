#!/bin/sh
# List controllable backlight devices, one per line:
#   name<TAB>model<TAB>max<TAB>cur
# model comes from the ddcci monitor id when present, else the device name.

for d in /sys/class/backlight/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    max=$(cat "$d/max_brightness" 2>/dev/null) || continue
    cur=$(cat "$d/brightness" 2>/dev/null) || continue
    model=$(cat "$d/device/idModel" 2>/dev/null)
    [ -n "$model" ] || model="$name"
    printf '%s\t%s\t%s\t%s\n' "$name" "$model" "$max" "$cur"
done
