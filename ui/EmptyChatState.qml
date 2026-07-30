import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    property bool isVisible: false

    anchors.centerIn: parent
    width: parent.width - (Theme.spacingL * 2)
    spacing: Theme.spacingM
    visible: isVisible

    StyledText {
        text: "No AI Models Available"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        color: Theme.surfaceText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    StyledText {
        text: "Please add your API keys in the settings screen to start chatting."
        font.pixelSize: Theme.fontSizeMedium
        horizontalAlignment: Text.AlignHCenter
        color: Theme.surfaceText
        opacity: 0.7
        width: parent.width
        wrapMode: Text.WordWrap
    }

    DankButton {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Configure in Settings"
        onClicked: Quickshell.execDetached(["dms", "ipc", "call", "settings", "openWith", "plugins"])                    
    }
}
