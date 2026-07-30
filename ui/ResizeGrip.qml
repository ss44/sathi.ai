import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

MouseArea {
    id: resizeHandle
    
    property string resizeCorner: "right"
    property real popoutWidth: 400
    property real popoutHeight: 500
    property string pluginId: ""
    property var pluginService: null

    // Dynamic anchoring based on resizeCorner setting
    anchors.right: (resizeCorner === "left") ? undefined : parent.right
    anchors.left: (resizeCorner === "left") ? parent.left : undefined
    anchors.bottom: parent.bottom
    
    width: 25
    height: 25
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
            ctx.lineWidth = 2;
            ctx.beginPath();
            
            // Diagonal lines
            var w = width;
            var h = height;
            
            if (resizeHandle.resizeCorner === "left") {
                // Draw lines in bottom-left corner / /
                ctx.moveTo(0, h - 10);
                ctx.lineTo(10, h);
                
                ctx.moveTo(0, h - 5);
                ctx.lineTo(5, h);
            } else {
                // Draw lines in bottom-right corner \ \ (or rather, the standard resize grip)
                ctx.moveTo(w, h - 10);
                ctx.lineTo(w - 10, h);
                
                ctx.moveTo(w, h - 5);
                ctx.lineTo(w - 5, h);
            }
            
            ctx.stroke();
        }
    }
}
