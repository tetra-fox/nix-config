pragma Singleton

import Quickshell.Hyprland
import QtQuick

// hyprland is in lua config mode, so dispatch arguments are lua
QtObject {
    function switchWorkspace(id: int): void {
        Hyprland.dispatch(`hl.dsp.event([[workspace ${id}]])`);
    }

    // for untrusted text, so it can't close the [[ ]] early and inject lua
    function escapeArg(s: string): string {
        return s.replace(/\]\]|\[\[|[\r\n]/g, "");
    }
}
