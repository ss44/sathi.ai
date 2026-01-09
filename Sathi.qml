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

    property var displayedEmojis: ["✨"]
    property bool isLoading: false
    
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            Repeater {
                model: root.displayedEmojis
                StyledText {
                    text: modelData
                    font.pixelSize: Theme.fontSizeLarge
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            Repeater {
                model: root.displayedEmojis
                StyledText {
                    text: modelData
                    font.pixelSize: Theme.fontSizeMedium
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    property ListModel chatModel: ListModel { }
    property ListModel availableAisModel: ListModel { }



    ChatBackendChat {
        id: backendChat
        apiKey: pluginData.geminiApiKey || ""
        running: false 
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
        running: false

        onNewMessage: (text, isError) => {
            console.log('got new settings message:', text, isError);
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
            if (pluginData.geminiApiKey) {
                console.log('running backends now!?')
                backendChat.running = true
                backendSettings.running = true
            }
        })
    }


    function processMessage(message) {
        console.log(pluginData.geminiApiKey);
        console.log(pluginData);        

        if (message === "") return;

        chatModel.append({ "text": message, "isUser": true, "shouldAnimate": false, "isThinking": false });
        root.isLoading = true;
        chatModel.append({ "text": "", "isUser": false, "shouldAnimate": true, "isThinking": true });

        backendChat.sendMessage(message);
    }

    function getPopoutContent() {
        const key = pluginData.geminiApiKey;
        if (key && key !== "") {
            console.log('i guess we got an api key!?')
            return chatPopout;
        } else {
            console.log("No API key set - is there a toast service!?"); 
            ToastService.showError("Script failed", "Exit code: " + exitCode)
        }
    }

    popoutContent: getPopoutContent()

    Component {
        id: chatPopout
        PopoutComponent {
            id: popoutColumn
            showCloseButton: true

            

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
                            console.log('model changed to:', currentValue);
                            getData('aiModel');
                            setData('aiModel', currentValue);

                            console.log('current value is now:', getData('aiModel'));
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 400
    popoutHeight: 500
}
