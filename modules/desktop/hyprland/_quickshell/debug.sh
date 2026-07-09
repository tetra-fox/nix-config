#!/usr/bin/env bash
QML_DIR="$(dirname "$0")/shell"

systemctl --user stop quickshell.service

# quickshell replaces .qmlls.ini with a symlink into its runtime vfs, whose
# hash-named dir under /run provides the qs.* modules. mirror it at a stable
# path so codium's qmlls finds it (qt-qml.qmlls.additionalImportPaths in the
# vscode qml.nix) without anything hardcoding the hash
refresh_vfs_link() {
    if [ -L "$QML_DIR/.qmlls.ini" ]; then
        mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"
        ln -sfT "$(dirname "$(readlink "$QML_DIR/.qmlls.ini")")" "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/qmlls-vfs"
    fi
}

trap 'refresh_vfs_link; systemctl --user start quickshell.service' EXIT

touch "$QML_DIR/.qmlls.ini"

quickshell \
    --path "$QML_DIR" \
    --log-times \
    -vv
