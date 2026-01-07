import QtQuick
import qs.Common 
import qs.Widgets

DankRectangle {
    id: root
    property string text: ""
    property bool isUser: false
    property bool shouldAnimate: false
    property string displayedText: ""
    
    signal animationCompleted()

    Timer {
        id: typeWriterTimer
        interval: 15
        repeat: true
        running: false
        property int currentIndex: 0
        
        onTriggered: {
            if (currentIndex < root.text.length) {
                var step = 1;
                // Speed up for longer texts
                if (root.text.length > 500) step = 5;
                else if (root.text.length > 200) step = 2;

                currentIndex += step;
                if (currentIndex > root.text.length) currentIndex = root.text.length;
                
                root.displayedText = root.text.substring(0, currentIndex);
            } else {
                running = false;
                root.animationCompleted();
            }
        }
    }

    Component.onCompleted: {
        if (root.isUser || !root.shouldAnimate) {
            root.displayedText = root.text;
        } else {
            typeWriterTimer.currentIndex = 0;
            typeWriterTimer.running = true;
        }
    }

    // @todo we want to address the bubble width so that its the total width of the child + padding 
    // unfortunately my attempts at this didn't work yet. So we'll keep the width fixed to its parent.
    width: parent.width 
    height: msgText.height + (Theme.spacingL * 2)

    // Alignment in the Column
    anchors.right: root.isUser ? parent.right : undefined
    anchors.left: root.isUser ? undefined : parent.left
    
    color: root.isUser ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
    radius: Theme.cornerRadius
    
    StyledText {
        id: msgText
        text: root.displayedText
        textFormat: Text.MarkdownText
        onLinkActivated: link => Qt.openUrlExternally(link)
        
        // Use full available width minus padding
        width: root.width - (Theme.spacingL * 2)
        wrapMode: Text.Wrap
        
        anchors.centerIn: parent
        color: Theme.surfaceText
    }    
}
