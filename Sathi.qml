import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Common
import qs.Modals.Spotlight
import qs.Modules.AppDrawer
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "."

PluginComponent {
    id: root

    layerNamespacePlugin: "dank:sathi-ai"

    property var displayedEmojis: ["✨"]

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

    ChatBackend {
        id: backend
        apiKey: pluginData.geminiApiKey || ""
        running: false 
        onNewMessage: (text, isError) => {
            chatModel.append({
                "text": text,
                "isUser": false,
                "shouldAnimate": true
            });
        }
    }

    Component.onCompleted: {
        // Delay start to ensure pluginData is ready and env vars are set
        Qt.callLater(() => {
            if (pluginData.geminiApiKey) {
                backend.running = true
            }
        })
    }

    function processMessage(message) {
        console.log(pluginData.geminiApiKey);
        console.log(pluginData);        

        if (message === "") return;

        chatModel.append({ "text": message, "isUser": true, "shouldAnimate": false });
        backend.sendMessage(message);
    }

    function getPopoutContent() {
        const key = pluginData.geminiApiKey;
        console.log(pluginData.geminiApiKey)
        console.log('key?', key)
        if (key && key !== "") {
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
                    anchors.bottom: chatInput.top
                    anchors.bottomMargin: Theme.spacingMedium
                    
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
                                width: chatColumn.width - (chatColumn.padding * 2)
                                onAnimationCompleted: model.shouldAnimate = false
                            }
                        }
                    }
                }

                // Dank Textfield at the bottom for user input
                ChatInput {
                    id: chatInput
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingLarge
                              
                    onAccepted: {
                        // Handle the input text here
                        console.log("User input:", text); 
                        root.processMessage(text);
                        
                        text = ""; // Clear input after processing
                    }
                }
            }
        }
    }

    popoutWidth: 400
    popoutHeight: 500
}
