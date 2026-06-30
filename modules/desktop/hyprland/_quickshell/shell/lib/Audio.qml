pragma Singleton

import QtQuick

// shared pipewire node helpers
QtObject {
    // channelmix.lock-volumes disables software volume/mute entirely on the node,
    // so the slider should not look interactive when it is set
    function locked(node): bool {
        return !!(node && node.properties && node.properties["channelmix.lock-volumes"] === "true");
    }
}
