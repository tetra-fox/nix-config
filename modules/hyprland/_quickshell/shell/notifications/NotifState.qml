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

    // group key for the center's per-app grouping; "" appName collapses to Unknown
    function groupKey(wrapper): string {
        return (wrapper.notif?.appName ?? "") || "Unknown";
    }
}
