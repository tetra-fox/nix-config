pragma Singleton

import Quickshell.Hyprland
import QtQuick

// session-ending actions go through hyprshutdown so apps and hyprland exit cleanly
QtObject {
    // run after hyprland exits
    readonly property string logout: "uwsm stop"
    readonly property string reboot: "uwsm stop; systemctl reboot"
    readonly property string shutdown: "uwsm stop; systemctl poweroff"

    // in lua config mode the dispatch argument is evaluated as lua. [[ ]] keeps the inner quotes
    function session(postCmd: string): void {
        Hyprland.dispatch(`hl.dsp.exec_cmd([[hyprshutdown -p '${postCmd}']])`);
    }

    function run(cmd: string): void {
        Hyprland.dispatch(`hl.dsp.exec_cmd([[${cmd}]])`);
    }
}
