import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "dank:sathi-ai"

    property var displayText: "✨"
    property bool isLoading: false
    property string aiModel: pluginData.aiModel
    property bool useGrounding: true
    property string systemPrompt: pluginData.systemPrompt || "You are a helpful assistant. Answer concisely. The chat client you are running in is small so keep answers brief. For context the current date is " + (new Date()).toDateString() + "." 
    property string pendingInputText: ""
    property string resizeCorner: pluginData.resizeCorner || "right"


    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            StyledText {
                text: root.displayText
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            StyledText {
                text: root.displayText
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    property ListModel chatModel: ListModel { }
    property ListModel availableAisModel: ListModel { }
    property bool isModelAvailable: true

    onAvailableAisModelChanged: {
        root.checkModelAvailability();
    }

    function checkModelAvailability() {
        if (!root.aiModel) {
            root.isModelAvailable = false; // Or false if strict, but if empty usually means not set/default
            return;
        }

        root.isModelAvailable = backendSettings.isModelAvailable(root.aiModel);
        console.log("Model availability for " + root.aiModel + ": " + root.isModelAvailable);
    }

    ChatBackendChat {
        id: backendChat
        geminiApiKey: pluginData.geminiApiKey || ""
        ollamaUrl: pluginData.ollamaUrl || ""
        model: root.aiModel
        useGrounding: root.useGrounding
        systemPrompt: root.systemPrompt

        onNewMessage: (text, isError) => {
            root.isLoading = false;
            // Remove the thinking bubble if it exists
            if (chatModel.count > 0) {
                 var last = chatModel.get(chatModel.count - 1);
                 if (last.isThinking === true) {
                     chatModel.remove(chatModel.count - 1);
                 }
            }
            chatModel.append({
                "text": text,
                "isUser": false,
                "shouldAnimate": true,
                "isThinking": false
            });
        }
    }

    ChatBackendSettings {
        id: backendSettings
        geminiApiKey: pluginData.geminiApiKey || ""
        ollamaUrl: pluginData.ollamaUrl || ""
        
        onNewModels: (models, isError) => {
            try {
                var data = JSON.parse(models);
                for (var i = 0; i < data.length; i++) {
                    availableAisModel.append(data[i]); // Append each item to the ListModel
                }
                root.checkModelAvailability();
            } catch (err) {
                console.error('failed to set models:', err)
            }
        }
    }

    function processMessage(message) {
        if (message === "") return;

        chatModel.append({ "text": message, "isUser": true, "shouldAnimate": false, "isThinking": false });
        root.isLoading = true;
        
        chatModel.append({ "text": "", "isUser": false, "shouldAnimate": true, "isThinking": true });
        backendChat.sendMessage(message);
    }

    function getPopoutContent() {
        const hasKey = pluginData.geminiApiKey || pluginData.ollamaUrl;

        if (hasKey) {
            return chatPopout;
        } else {
            // console.log("No API key set - is there a toast service!?"); 
            ToastService.showError("Script failed", "Exit code: " + exitCode)
        }
    }

    popoutContent: getPopoutContent()

    Component {
        id: chatPopout
        PopoutComponent {
            id: popoutColumn
            showCloseButton: true

            onVisibleChanged: {
                if (visible) {
                    console.log("PopoutComponent visible");
                     chatInput.forceActiveFocus();
                     chatInput.cursorPosition = chatInput.length;
                }
            }            

            Item {
                width: parent.width
                height: root.popoutHeight - popoutColumn.headerHeight -
                               popoutColumn.detailsHeight - Theme.spacingL

                Flickable { 
                    id: flickable
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: columnBottomSection.top
                    anchors.bottomMargin: Theme.spacingL
                   
                    contentWidth: width
                    contentHeight: chatColumn.height
                    clip: true
                    flickableDirection: Flickable.VerticalFlick

                    function scrollToBottom() {
                        if (contentHeight > height)
                            contentY = contentHeight - height;
                    }

                    Column {
                        id: chatColumn
                        width: parent.width
                        spacing: Theme.spacingL
                        padding: Theme.spacingL
                        
                        onHeightChanged: flickable.scrollToBottom()
                        
                        
                        Repeater {
                            model: root.chatModel
                            delegate: ChatBubble {
                                text: model.text
                                isUser: model.isUser
                                shouldAnimate: model.shouldAnimate
                                isThinking: model.isThinking !== undefined ? model.isThinking : false
                                width: chatColumn.width - (chatColumn.padding * 2)
                                onAnimationCompleted: model.shouldAnimate = false
                            }
                        }

                    }
                }

                Column { 
                    id: columnBottomSection
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingL
                    // anchors.bottomMargin: Theme.spacingL
                    // bottomPadding: 20
                    
                    spacing: Theme.spacingXS
                    
                    width: parent.width
                    // height: 75

                    // Dank Textfield at the bottom for user input
                    ChatInput {
                        id: chatInput
                        width: parent.width
                        text: root.pendingInputText
                        onTextChanged: root.pendingInputText = text

                        // anchors.bottomMargin: Theme.spacingL
                        // anchors.margins: Theme.spacingL
                        onAccepted: {
                            // Handle the input text here
                            console.log("User input:", text); 
                            root.processMessage(text);
                            
                            text = ""; // Clear input after processing
                             // Explicitly clear parent property just to be safe, 
                             // though the binding above should verify it via onTextChanged
                             root.pendingInputText = ""
                            text = ""; // Clear input after processing
                        }
                    }

                    // Display a small combo box at the bottom to change the model dynamically.
                    AiSelector {
                        id: cbModelSelector
                        model: availableAisModel
                        maxPopupHeight: popoutColumn.height * 0.6

                        currentValue: root.aiModel
                        width: parent.width
                        textRole: "display_name"
                        valueRole: "name"
                        displayText: currentIndex === -1 ? "Select an AI Model..." : currentText

                        onActivated: {
                            if (pluginService) {
                                root.aiModel = currentValue
                                pluginService.savePluginData(pluginId, "aiModel", currentValue)
                                root.checkModelAvailability()
                            }
                        }
                    }

                    StyledText {
                        visible: !root.isModelAvailable && root.aiModel !== "" && availableAisModel.count > 0
                        color: Theme.error
                        font.pixelSize: Theme.fontSizeSmall
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        anchors.bottomMargin: Theme.spacingM

                        function getText() {
                            if (availableAisModel.count === 0) {
                                return "⚠️ No models are currently available. Please check your API keys and connection.";
                            } else {
                                return "⚠️ Selected model \"" + root.aiModel + "\" is currently not available";
                            }
                        }
                        
                        text: getText()}
                }

                MouseArea {
                    id: resizeHandle
                    // Dynamic anchoring based on resizeCorner setting
                    anchors.right: (root.resizeCorner === "left") ? undefined : parent.right
                    anchors.left: (root.resizeCorner === "left") ? parent.left : undefined
                    anchors.bottom: parent.bottom
                    
                    width: 25
                    height: 25
                    // Switch cursor shape depending on side
                    cursorShape: (root.resizeCorner === "left") ? Qt.SizeBDiagCursor : Qt.SizeFDiagCursor
                    
                    property point startGlobalPos
                    property real startWidth
                    property real startHeight

                    onPressed: (mouse) => {
                        startGlobalPos = mapToGlobal(mouse.x, mouse.y)
                        startWidth = root.popoutWidth
                        startHeight = root.popoutHeight
                    }

                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            var currentGlobal = mapToGlobal(mouse.x, mouse.y)
                            var dx = currentGlobal.x - startGlobalPos.x
                            var dy = currentGlobal.y - startGlobalPos.y
                            
                            if (root.resizeCorner === "left") {
                                // For left-side resize, moving mouse LEFT (negative dx) should INCREASE width
                                root.popoutWidth = Math.max(350, startWidth - dx)
                            } else {
                                // For right-side resize, moving mouse RIGHT (positive dx) should INCREASE width
                                root.popoutWidth = Math.max(350, startWidth + dx)
                            }
                            
                            // Height always increases when moving DOWN (positive dy)
                            root.popoutHeight = Math.max(400, startHeight + dy)
                        }
                    }
                    
                    onReleased: {
                         if (pluginService) {
                             pluginService.savePluginData(pluginId, "windowWidth", root.popoutWidth)
                             pluginService.savePluginData(pluginId, "windowHeight", root.popoutHeight)
                         }
                    }

                    Canvas {
                        anchors.fill: parent
                        anchors.margins: 4
                        // Redraw when the corner changes
                        property string corner: root.resizeCorner
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
                            
                            if (root.resizeCorner === "left") {
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
            }
        }
    }

    popoutWidth: pluginData.windowWidth || 400
    popoutHeight: pluginData.windowHeight || 500
}
