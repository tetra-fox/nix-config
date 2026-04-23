#!/usr/bin/env bash
QML_DIR="$(dirname "$0")/shell"

systemctl --user stop quickshell.service

trap 'systemctl --user start quickshell.service' EXIT

touch "$QML_DIR/.qmlls.ini"

quickshell \
    --path "$QML_DIR" \
    --log-times \
    -vv
