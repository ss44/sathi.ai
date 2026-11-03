import QtQuick
import Quickshell
import qs.Common
import qs.Services

MouseArea {
    id: resizeHandle
    
    property string resizeCorner: "right"
    property real popoutWidth: 400
    property real popoutHeight: 500
    property string pluginId: ""
    property var pluginService: null
    readonly property real gripSize: Theme.spacingXL

    // Dynamic anchoring based on resizeCorner setting
    anchors.right: (resizeCorner === "left") ? undefined : parent.right
    anchors.left: (resizeCorner === "left") ? parent.left : undefined
    anchors.bottom: parent.bottom
    
    width: gripSize
    height: gripSize
    // Switch cursor shape depending on side
    cursorShape: (resizeCorner === "left") ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
    
    property point startGlobalPos
    property real startWidth
    property real startHeight

    onPressed: (mouse) => {
        startGlobalPos = mapToGlobal(mouse.x, mouse.y)
        startWidth = popoutWidth
        startHeight = popoutHeight
    }

    onPositionChanged: (mouse) => {
        if (pressed) {
            var currentGlobal = mapToGlobal(mouse.x, mouse.y)
            var dx = currentGlobal.x - startGlobalPos.x
            var dy = currentGlobal.y - startGlobalPos.y
            
            if (resizeCorner === "left") {
                // For left-side resize, moving mouse LEFT (negative dx) should INCREASE width
                popoutWidth = Math.max(350, startWidth - dx)
            } else {
                // For right-side resize, moving mouse RIGHT (positive dx) should INCREASE width
                popoutWidth = Math.max(350, startWidth + dx)
            }
            
            // Height always increases when moving DOWN (positive dy)
            popoutHeight = Math.max(400, startHeight + dy)
        }
    }
    
    onReleased: {
         if (pluginService && pluginId) {
             pluginService.savePluginData(pluginId, "windowWidth", popoutWidth)
             pluginService.savePluginData(pluginId, "windowHeight", popoutHeight)
         }
    }

    Canvas {
        anchors.fill: parent
        anchors.margins: 4
        // Redraw when the corner changes
        property string corner: resizeHandle.resizeCorner
        onCornerChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.strokeStyle = Theme.surfaceText;
            ctx.lineCap = "round";
            ctx.lineWidth = Theme.outlineWidthFocused;
            ctx.beginPath();
            
            // Diagonal lines
            var w = width;
            var h = height;
            
            if (resizeHandle.resizeCorner === "left") {
                // Draw lines in bottom-left corner / /
                ctx.moveTo(0, h - Theme.spacingM);
                ctx.lineTo(Theme.spacingM, h);
                
                ctx.moveTo(0, h - Theme.spacingXS);
                ctx.lineTo(Theme.spacingXS, h);
            } else {
                // Draw lines in bottom-right corner \ \ (or rather, the standard resize grip)
                ctx.moveTo(w, h - Theme.spacingM);
                ctx.lineTo(w - Theme.spacingM, h);
                
                ctx.moveTo(w, h - Theme.spacingXS);
                ctx.lineTo(w - Theme.spacingXS, h);
            }
            
            ctx.stroke();
        }
    }
}
