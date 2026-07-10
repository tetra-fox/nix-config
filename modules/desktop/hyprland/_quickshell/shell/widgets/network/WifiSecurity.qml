pragma Singleton

import Quickshell.Networking
import QtQuick

// single home for the open-network predicate: the delegate's lock icon and
// WifiSection's psk-prompt decision must agree or they drift
QtObject {
    function isOpen(security): bool {
        return security === WifiSecurityType.Open || security === WifiSecurityType.Unknown; // qmllint disable unresolved-type
    }
}
