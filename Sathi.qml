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
    property string aiModel: pluginData.aiModel || "gemini-flash-latest"
    property bool useGrounding: true
    property string systemPrompt: pluginData.systemPrompt || "You are a helpful assistant. Answer concisely. The chat client you are running in is small so keep answers brief. For context the current date is " + (new Date()).toDateString() + "." 

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



    ChatBackendChat {
        id: backendChat
        apiKey: pluginData.geminiApiKey || ""
        ollamaUrl: pluginData.ollamaUrl || ""
        running: false 
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
        apiKey: pluginData.geminiApiKey || ""
        ollamaUrl: pluginData.ollamaUrl || ""
        running: false
        onNewMessage: (text, isError) => {
            try {
                var data = JSON.parse(text);
                for (var i = 0; i < data.length; i++) {
                    availableAisModel.append(data[i]); // Append each item to the ListModel
                }

                console.log('models set to ', availableAisModel);
            } catch (err) {
                console.error('failed to set models:', err)
            }
        }
    }

    Component.onCompleted: {
        // Delay start to ensure pluginData is ready and env vars are set
        
        Qt.callLater(() => {
            if (pluginData.geminiApiKey || pluginData.ollamaUrl) {
                console.log('running backends now!?')
                backendChat.running = true
                backendSettings.running = true
            }
        })
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
                        focus: true
                        // anchors.bottomMargin: Theme.spacingL
                        // anchors.margins: Theme.spacingL
                        onAccepted: {
                            // Handle the input text here
                            console.log("User input:", text); 
                            root.processMessage(text);
                            
                            text = ""; // Clear input after processing
                        }
                    }

                    // Display a small combo box at the bottom to change the model dynamically.
                    AiSelector {
                        id: cbModelSelector
                        model: availableAisModel
                        maxPopupHeight: popoutColumn.height * 0.6

                        currentValue: pluginData.aiModel ||  "gemini-flash-latest"
                        width: parent.width
                        textRole: "display_name"
                        valueRole: "name"

                        onActivated: {
                            if (pluginService) {
                                root.aiModel = currentValue
                                pluginService.savePluginData(pluginId, "aiModel", currentValue)
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 400
    popoutHeight: 500
}
