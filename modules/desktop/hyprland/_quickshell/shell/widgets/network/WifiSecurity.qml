pragma Singleton

import Quickshell.Networking
import QtQuick

// the delegate's lock icon and WifiSection's psk prompt must agree
QtObject {
    function isOpen(security): bool {
        return security === WifiSecurityType.Open || security === WifiSecurityType.Unknown; // qmllint disable unresolved-type
    }
}
