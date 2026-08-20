import QtQuick
import Quickshell

Item {
    id: root

    property var manifest
    property bool activated: false
    readonly property string pluginDir: String(manifest && manifest.__sourceDir ? manifest.__sourceDir : "")

    function activateIfReady() {
        if (activated || pluginDir.length === 0)
            return

        activated = true
        Quickshell.execDetached(["bash", pluginDir + "/activate.sh", "enable"])
    }

    onManifestChanged: activateIfReady()
    onPluginDirChanged: activateIfReady()

    Component.onDestruction: Quickshell.execDetached([
        "hyprctl", "eval",
        "for _, d in ipairs({ 'left', 'right', 'up', 'down' }) do "
            + "hl.gesture({ fingers = 3, direction = d, action = 'unset' }) end; "
            + "_G.omagestures = nil"
    ])
}
