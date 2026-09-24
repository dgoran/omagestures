import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    property var manifest
    property bool activated: false

    // The host strips __sourceDir from third-party manifests, so fall back to
    // this file's own location, which is always the plugin directory.
    readonly property string pluginDir: {
        var fromManifest = String(manifest && manifest.__sourceDir ? manifest.__sourceDir : "")
        if (fromManifest.length > 0)
            return fromManifest

        var own = String(Qt.resolvedUrl("."))
        if (own.indexOf("file://") === 0)
            own = own.substring(7)
        return own.replace(/\/+$/, "")
    }

    function activate() {
        if (pluginDir.length === 0)
            return

        activated = true
        Quickshell.execDetached(["bash", pluginDir + "/activate.sh", "enable"])
    }

    function activateIfReady() {
        if (activated)
            return

        activate()
    }

    onManifestChanged: activateIfReady()
    onPluginDirChanged: activateIfReady()
    Component.onCompleted: activateIfReady()

    // A Hyprland config reload rebuilds the Lua runtime, dropping the gestures
    // and in-memory state this plugin installed through hyprctl eval.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event || !event.name)
                return
            if (String(event.name) === "configreloaded" && root.activated)
                root.activate()
        }
    }

    // Disable goes through the activation script so removal clears the
    // four-finger workspace gestures as well as the three-finger snap.
    Component.onDestruction: {
        if (pluginDir.length === 0)
            return
        Quickshell.execDetached(["bash", pluginDir + "/activate.sh", "disable"])
    }
}
