pragma Singleton

import Quickshell.Hyprland
import QtQuick

// hyprland dispatch helpers. dispatched as lua since hyprland's config is lua mode;
// the [[ ]] long-bracket preserves the inner string. id is an int, so no escaping needed.
QtObject {
    function switchWorkspace(id: int): void {
        Hyprland.dispatch(`hl.dsp.event([[workspace ${id}]])`);
    }

    // for dispatch arguments built from untrusted text (dbus fields etc): strip
    // the lua long-bracket delimiters and newlines so the text cannot close the
    // [[ ]] early and inject lua
    function escapeArg(s: string): string {
        return s.replace(/\]\]|\[\[|[\r\n]/g, "");
    }
}
