#!/usr/bin/env bash
# Kill any existing instance first so we get a clean run
quickshell kill --path "$(dirname "$0")/qml" 2>/dev/null

exec quickshell \
    --path "$(dirname "$0")/qml" \
    --log-times \
    -vv
