import QtQuick
import QtQuick.Controls
import qs.Common

TextArea {
    id: root

    signal accepted()

    color: Theme.surfaceText
    font.pixelSize: Theme.fontSizeMedium
    selectedTextColor: Theme.onPrimary
    selectionColor: Theme.primary

    wrapMode: TextEdit.Wrap
    
    background: Rectangle {
        implicitHeight: Theme.fieldHeight
        color: Theme.chipSurface
        radius: Theme.cornerRadius
        border.width: root.activeFocus ? Theme.outlineWidthFocused : Theme.outlineWidth
        border.color: root.activeFocus ? Theme.primary : Theme.outlineVariant

        // Keep the placeholder inside the field; the box does not have a notched outline label
        Text {
            id: placeholderLabel
            text: "Type a message..."
            color: root.activeFocus ? Theme.primary : Theme.onSurfaceVariant
            font.pixelSize: Theme.fontSizeMedium
            visible: root.length === 0

            x: Theme.spacingM
            y: (parent.height - height) / 2
        }
    }

    padding: Theme.spacingM

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (event.modifiers & Qt.ShiftModifier) {
                // Allow new line implicitly by not accepting the event
                event.accepted = false; 
            } else {
                event.accepted = true;
                root.accepted();
            }
        }
    }
}
