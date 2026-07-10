pragma ComponentBehavior: Bound

import qs.components
import qs.lib
import Quickshell
import QtQuick

// one tray menu row: plain trigger, checkbox/radio item, or an inline-expanding
// submenu. children are only fetched from dbus while expanded
Column {
    id: root

    required property var entry

    // a leaf entry was triggered somewhere in this subtree; the popup closes on it
    signal activated

    property bool expanded: false

    MenuItem {
        width: parent.width
        text: root.entry.text
        enabled: root.entry.enabled
        isSeparator: root.entry.isSeparator
        icon: {
            switch (root.entry.buttonType) {
            case QsMenuButtonType.CheckBox:
                if (root.entry.checkState === Qt.Checked)
                    return Icons.checkBox;
                if (root.entry.checkState === Qt.PartiallyChecked)
                    return Icons.indeterminateCheckBox;
                return Icons.checkBoxBlank;
            case QsMenuButtonType.RadioButton:
                return root.entry.checkState === Qt.Checked ? Icons.radioChecked : Icons.radioUnchecked;
            default:
                return "";
            }
        }
        rightIcon: root.entry.hasChildren ? (root.expanded ? Icons.expandMore : Icons.chevronRight) : ""
        onClicked: {
            if (root.entry.hasChildren) {
                root.expanded = !root.expanded;
            } else {
                root.entry.triggered();
                root.activated();
            }
        }
    }

    Loader {
        width: parent.width
        active: root.expanded
        visible: active

        sourceComponent: Column {
            leftPadding: 12

            QsMenuOpener {
                id: subOpener
                menu: root.entry    // qmllint disable unresolved-type
            }

            Repeater {
                model: subOpener.children    // qmllint disable missing-property

                delegate: Loader {
                    required property var modelData
                    width: parent.width - parent.leftPadding
                    // loading by file name breaks the self-reference cycle a
                    // direct TrayMenuEntry declaration would be
                    Component.onCompleted: {
                        setSource("TrayMenuEntry.qml", {
                            entry: modelData
                        });
                        item.activated.connect(root.activated);
                    }
                }
            }
        }
    }
}
