pragma Singleton

import qs.lib
import Quickshell.Services.Notifications
import QtQuick

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

    function urgencyColor(urgency): color {
        if (urgency === NotificationUrgency.Critical)
            return Theme.colorRed;
        if (urgency === NotificationUrgency.Low)
            return Theme.colorYellow;
        return Theme.accent;
    }

    // some senders omit the summary
    function title(notif): string {
        return notif.summary !== "" ? notif.summary : notif.appName;
    }

    // chromium browsers prepend an <a> line with the site url, duplicating appName.
    // same as Ambxst's processNotificationBody
    function cleanBody(body: string, appName: string): string {
        if (!body || !appName)
            return body || "";
        const lower = appName.toLowerCase();
        const isChromium = ["brave", "chrome", "chromium", "vivaldi", "opera", "microsoft edge"].some(n => lower.includes(n));
        if (!isChromium)
            return body;
        const lines = body.split("\n\n");
        if (lines.length > 1 && lines[0].startsWith("<a"))
            return lines.slice(1).join("\n\n");
        return body;
    }

    // the spec's "default" action, i.e. jump to the source. false when there is none
    function activate(notif): bool {
        const def = (notif.actions ?? []).find(a => a.identifier === "default");
        if (def) {
            def.invoke();
            return true;
        }
        return false;
    }

    function dismissAll(list): void {
        for (const w of list)
            w.notif.dismiss();
    }

    // not a delegate-local timer: list changes can destroy the delegate mid-collapse
    // and the notification would come back
    property var _pendingDismiss: []
    function dismissLater(wrapper): void {
        if (wrapper.dismissing)
            return;
        wrapper.dismissing = true;
        root._pendingDismiss.push(wrapper);
        _dismissDelay.restart();
    }

    property Timer _dismissDelay: Timer {
        // just past the collapse animation, same as NotificationCard
        interval: Theme.animSlow + 30
        onTriggered: {
            for (const w of root._pendingDismiss) {
                // null if the notif was closed externally meanwhile
                if (w && w.notif)
                    w.notif.dismiss();
            }
            root._pendingDismiss = [];
        }
    }

    function groupKey(wrapper): string {
        return (wrapper.notif?.appName ?? "") || "Unknown";
    }
}
