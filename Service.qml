import QtQuick
import Quickshell

Item {
    id: root

    property string omarchyPath: ""
    property var shell
    property var manifest
    property var pluginRegistry

    property bool activated: false
    readonly property string pluginDir: String(manifest && manifest.__sourceDir ? manifest.__sourceDir : "")

    function activateIfReady() {
        if (activated || pluginDir.length === 0)
            return

        activated = true
        Quickshell.execDetached(["bash", pluginDir + "/activate.sh", "enable", pluginDir])
    }

    onManifestChanged: activateIfReady()
    onPluginDirChanged: activateIfReady()

    Component.onDestruction: {
        if (pluginDir.length > 0)
            Quickshell.execDetached(["bash", pluginDir + "/activate.sh", "disable", pluginDir])
    }
}
