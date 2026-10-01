import QtQuick
import qs.Common
import qs.Widgets

DankTextField {
    id: root

    placeholderText: "Type a message..."
    font.pixelSize: Theme.fontSizeMedium
    textColor: Theme.surfaceText
    backgroundColor: Theme.surfaceContainerHigh
    
    // DankTextField emits accepted when Enter is pressed
}
