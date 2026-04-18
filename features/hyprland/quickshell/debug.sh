#!/usr/bin/env bash
QML_DIR="$(dirname "$0")/qml"

systemctl --user stop quickshell.service

trap 'systemctl --user start quickshell.service' EXIT

quickshell \
    --path "$QML_DIR" \
    --log-times \
    -vv
