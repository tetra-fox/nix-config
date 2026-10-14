pragma Singleton

import QtQuick

QtObject {
    // channelmix.lock-volumes disables software volume and mute on the node
    function locked(node): bool {
        return !!(node && node.properties && node.properties["channelmix.lock-volumes"] === "true");
    }
}
