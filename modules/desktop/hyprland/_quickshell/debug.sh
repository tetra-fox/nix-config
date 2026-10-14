#!/usr/bin/env bash
QML_DIR="$(dirname "$0")/shell"

systemctl --user stop quickshell.service

# quickshell symlinks .qmlls.ini into a hash-named vfs dir under /run. mirror it at a
# stable path for codium's qmlls (additionalImportPaths in the vscode qml.nix)
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
