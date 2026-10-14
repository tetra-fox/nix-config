pragma Singleton

import Quickshell
import QtQuick

QtObject {
    id: root

    // bumped after each DesktopEntries scan, bindings reading it re-evaluate
    property int rev: 0

    property Connections _conn: Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.rev++;
        }
    }

    // heuristicLookup("") returns the first entry with no StartupWMClass
    function entry(appId) {
        return appId ? DesktopEntries.heuristicLookup(appId) : null;
    }

    function name(appId) {
        return root.entry(appId)?.name ?? appId ?? "";
    }
}
