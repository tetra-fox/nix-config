import qs.lib

import Quickshell.Services.Notifications
import QtQuick

// notif image with fallback chain: notif.image -> notif.appIcon -> material icon
Item {
    id: root

    required property Notification notif
    property color accentColor: Theme.accent
    property int size: Theme.fontIconLg

    implicitWidth: size
    implicitHeight: size

    Text {
        anchors.centerIn: parent
        text: Icons.notifications
        color: root.accentColor
        font.family: Theme.fontIconFamily
        font.pixelSize: root.size
        visible: img.status !== Image.Ready
    }

    Image {
        id: img
        anchors.fill: parent
        source: {
            if (!root.notif)
                return "";
            if (root.notif.image !== "")
                return root.notif.image;
            if (root.notif.appIcon !== "")
                return root.notif.appIcon;
            return "";
        }
        visible: status === Image.Ready
        sourceSize.width: root.size
        sourceSize.height: root.size
        fillMode: Image.PreserveAspectFit
    }
}
