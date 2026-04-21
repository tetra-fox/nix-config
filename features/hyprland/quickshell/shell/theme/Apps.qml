pragma Singleton

import QtQuick

// appId → display name, with overrides for apps whose appId
// doesn't capitalize nicely with charAt(0).toUpperCase()
QtObject {
    readonly property var titleOverrides: ({
            "1password": "1Password",
            "org.telegram.desktop": "Telegram",
            "org.prismlauncher.PrismLauncher": "Prism Launcher",
            "com.usebottles.bottles": "Bottles"
        })

    function name(appId) {
        if (!appId)
            return "";
        return titleOverrides[appId] ?? appId.charAt(0).toUpperCase() + appId.slice(1);
    }
}
