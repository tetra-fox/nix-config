pragma Singleton

import qs.lib
import Quickshell.Services.Notifications
import QtQuick

// global notification state (DND) plus shared notif-rendering helpers.
// in-memory; resets on shell restart.
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

    // accent color by urgency, shared by the popup card and the center item
    function urgencyColor(urgency): color {
        if (urgency === NotificationUrgency.Critical)
            return Theme.colorRed;
        if (urgency === NotificationUrgency.Low)
            return Theme.colorYellow;
        return Theme.accent;
    }

    // fall back to appName when summary is empty (some servers send body-only notifs)
    function title(notif): string {
        return notif.summary !== "" ? notif.summary : notif.appName;
    }

    // chromium-family browsers prepend an <a> line with the originating site URL to the
    // body, duplicating appName. strip it. matches Ambxst's processNotificationBody helper.
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

    // invoke the spec's "default" action: what "click the notification to jump to
    // the source" means (e.g. discord opens the message). returns true when there
    // was a default action to invoke, so callers can fall back otherwise. only valid
    // while the notif is live, which persisted center notifs still are
    function activate(notif): bool {
        const def = (notif.actions ?? []).find(a => a.identifier === "default");
        if (def) {
            def.invoke();
            return true;
        }
        return false;
    }

    // dismiss every notif in a wrapper list (clear-all, per-app clear on a filtered subset)
    function dismissAll(list): void {
        for (const w of list)
            w.notif.dismiss();
    }

    // delegate-independent delayed dismiss for the center: list changes rebuild
    // the group model and can destroy item delegates, so a delegate-local timer
    // would be cancelled mid-collapse and the notification would resurrect. the
    // pending flag lives on the wrapper and the timer here, both of which
    // survive delegate churn
    property var _pendingDismiss: []
    function dismissLater(wrapper): void {
        if (wrapper.dismissing)
            return;
        wrapper.dismissing = true;
        root._pendingDismiss.push(wrapper);
        _dismissDelay.restart();
    }

    property Timer _dismissDelay: Timer {
        // slightly past the collapse animation, same derivation as NotificationCard
        interval: Theme.animSlow + 30
        onTriggered: {
            for (const w of root._pendingDismiss) {
                // a wrapper destroyed inside the window (notif closed externally)
                // reads as null
                if (w && w.notif)
                    w.notif.dismiss();
            }
            root._pendingDismiss = [];
        }
    }

    // group key for the center's per-app grouping; "" appName collapses to Unknown
    function groupKey(wrapper): string {
        return (wrapper.notif?.appName ?? "") || "Unknown";
    }
}
