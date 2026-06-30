pragma Singleton

import Quickshell
import QtQuick

// desktop-entry lookup helper, reactive to the async DesktopEntries scan
QtObject {
    id: root

    // bumped when DesktopEntries finishes (re)scanning, so bindings that
    // reference `rev` re-evaluate once entries are actually available
    property int rev: 0

    property Connections _conn: Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.rev++;
        }
    }

    // guards against heuristicLookup("") returning the first entry with
    // no StartupWMClass
    function entry(appId) {
        return appId ? DesktopEntries.heuristicLookup(appId) : null;
    }

    function name(appId) {
        return root.entry(appId)?.name ?? appId ?? "";
    }
}
