pragma Singleton

import Quickshell.Hyprland
import QtQuick

// single source of truth for session power commands
// session-ending actions go through hyprshutdown so it can show the shutdown UI,
// exit apps and hyprland cleanly, then run the post-cmd. suspend stays a plain exec.
QtObject {
    // post-cmd run after hyprland has exited
    readonly property string logout: "uwsm stop"
    readonly property string reboot: "uwsm stop; systemctl reboot"
    readonly property string shutdown: "uwsm stop; systemctl poweroff"

    // exit the session via hyprshutdown, then run postCmd
    // dispatched as lua since hyprland's config is lua mode, where the ipc dispatch
    // argument is evaluated as lua. [[ ]] preserves the inner single quotes.
    function session(postCmd: string): void {
        Hyprland.dispatch(`hl.dsp.exec_cmd([[hyprshutdown -p '${postCmd}']])`);
    }

    // run a command without tearing down the session (e.g. suspend)
    function run(cmd: string): void {
        Hyprland.dispatch(`hl.dsp.exec_cmd([[${cmd}]])`);
    }
}
