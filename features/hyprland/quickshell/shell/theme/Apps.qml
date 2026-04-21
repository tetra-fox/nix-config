pragma Singleton

import Quickshell
import QtQuick

// appId → display name via the desktop entry's Name field,
// falling back to capitalizing the appId
QtObject {
    function name(appId) {
        if (!appId)
            return "";
        const entry = DesktopEntries.heuristicLookup(appId);
        if (entry?.name)
            return entry.name;
        return appId.charAt(0).toUpperCase() + appId.slice(1);
    }
}
