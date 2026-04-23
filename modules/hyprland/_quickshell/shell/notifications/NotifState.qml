pragma Singleton

import QtQuick

// global notification state (DND). in-memory; resets on shell restart.
QtObject {
    id: root

    property bool dnd: false

    function toggleDnd(): void {
        root.dnd = !root.dnd;
    }
    function enableDnd(): void {
        root.dnd = true;
    }
    function disableDnd(): void {
        root.dnd = false;
    }
}
