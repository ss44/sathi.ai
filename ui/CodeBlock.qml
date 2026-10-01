import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common 
import qs.Widgets
import "../Syntax.js" as Syntax

Rectangle {
    id: root
    property string code: ""
    property string language: ""

    color: Theme.surfaceContainerHighest // Dark background for code
    radius: Theme.cornerRadius
    border.color: Theme.surfaceVariant
    border.width: 1
    
    implicitHeight: column.height + Theme.spacingM

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            height: Theme.fontSizeLarge * 2
            color: Theme.surfaceContainerHighest
            topLeftRadius: Theme.cornerRadius
            topRightRadius: Theme.cornerRadius
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingM

                Text {
                    text: root.language ? root.language : "code"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 60
                    height: Theme.fontSizeLarge * 1.5
                    radius: Theme.cornerRadius
                    color: copyArea.pressed ? Theme.primaryContainer : "transparent"
                    border.color: copyArea.containsMouse ? Theme.primary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: copyTimer.running ? "Copied!" : "Copy"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    
                    MouseArea {
                        id: copyArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            clipboardHelper.text = root.code
                            clipboardHelper.selectAll()
                            clipboardHelper.copy()
                            copyTimer.start()
                        }
                    }
                }
            }
        }

        // Code Content
        TextEdit {
            Layout.fillWidth: true
            Layout.margins: Theme.spacingM
            
            text: Syntax.highlight(root.code, root.language)
            font.family: "Monospace"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText 
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.RichText 
            tabStopDistance: 20 // Ensure tabs have a visible width
        }
    }
    
    TextEdit {
        id: clipboardHelper
        visible: false
    }
    
    Timer {
        id: copyTimer
        interval: 2000
        repeat: false
    }
}
