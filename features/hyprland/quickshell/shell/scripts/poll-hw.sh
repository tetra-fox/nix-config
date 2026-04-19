#!/bin/sh
# Poll hardware metrics. Output: key=value lines.
# Covers: CPU temp/freq, GPU, VRAM, disk.

# ── CPU ─────────────────────────────────────────────────────────────────

# k10temp (AMD) or coretemp (Intel), fall back to thermal_zone0
cputemp=""
for f in /sys/class/hwmon/hwmon*/temp1_input; do
    n=$(cat "${f%temp1_input}name" 2>/dev/null)
    if [ "$n" = k10temp ] || [ "$n" = coretemp ]; then
        cputemp=$(cat "$f")
        break
    fi
done
[ -z "$cputemp" ] && cputemp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
[ -n "$cputemp" ] && echo "cputemp=$cputemp"

freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
[ -n "$freq" ] && echo "cpufreq=$freq"

# ── GPU ─────────────────────────────────────────────────────────────────

gpu=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)

if [ -n "$gpu" ]; then
    # AMD — read sysfs directly
    echo "gpu=$gpu"
    vram_u=0; vram_t=0
    for f in /sys/class/drm/card*/device/mem_info_vram_used; do
        [ -f "$f" ] && vram_u=$(cat "$f") && break
    done
    for f in /sys/class/drm/card*/device/mem_info_vram_total; do
        [ -f "$f" ] && vram_t=$(cat "$f") && break
    done
    echo "vram=$vram_u $vram_t"

elif command -v nvidia-smi >/dev/null 2>&1; then
    # NVIDIA — single nvidia-smi call
    nvidia-smi \
        --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
        --format=csv,noheader,nounits \
    | {
        IFS=', ' read -r g vu vt t
        echo "gpu=$g"
        echo "vram=$((vu * 1048576)) $((vt * 1048576))"
        echo "gputemp=$t"
    }

else
    echo "gpu=-1"
fi

# ── Disk ────────────────────────────────────────────────────────────────

df -B1 / | awk 'NR==2 { print "disk=" $3 " " $2 }'
