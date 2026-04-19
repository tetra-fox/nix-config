#!/bin/sh
# Gather static system info. Output: key=value lines.

echo "kernel=$(uname -r)"
echo "uid=$(id -u)"

cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 \
  | sed 's/AMD //;s/Intel //;s/(R)//g;s/(TM)//g;s/ CPU//;s/ [0-9]*-Core Processor//' \
  | xargs)
echo "cpu_model=$cpu_model"

echo "cpu_cores=$(nproc)"

gpu_model=$(lspci 2>/dev/null | grep -Ei 'vga|3d' | head -1 | sed 's/.*\[//;s/\].*//')
echo "gpu_model=$gpu_model"

# shellcheck disable=SC1091
. /etc/os-release 2>/dev/null
echo "os=$PRETTY_NAME"
