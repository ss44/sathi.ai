import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modals.Common

Column { 
    id: columnBottomSection

    property var availableAisModel
    property string aiModel
    property bool isModelAvailable
    property string pendingInputText
    property bool popoutSticky
    property real popoutHeight
    property string pluginId
    property var pluginService

    signal processMessage(string message)
    signal clearChat()
    signal toggleSticky()
    signal checkModelAvailability()

    function focusInput() {
        chatInput.forceActiveFocus();
        chatInput.cursorPosition = chatInput.length;
    }

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Theme.spacingL
    visible: availableAisModel.count > 0

    spacing: Theme.spacingXS
    
    width: parent.width

    // Dank Textfield at the bottom for user input
    ChatInput {
        id: chatInput
        width: parent.width
        text: columnBottomSection.pendingInputText
        onTextChanged: columnBottomSection.pendingInputText = text

        onAccepted: {
            // Handle the input text here
            console.debug("User input:", text); 
            columnBottomSection.processMessage(text);
            
            text = ""; // Clear input after processing
            columnBottomSection.pendingInputText = ""
            text = ""; // Clear input after processing
        }
    }

    // Display a small combo box at the bottom to change the model dynamically.
    Row {
        id: bottomModelSelectorRow
        width: parent.width
        height: cbModelSelector.implicitHeight + Theme.spacingXL
        spacing: Theme.spacingS
        anchors.bottomMargin: Theme.spacingXL

        DankActionButton {
            id: btnSettings
            anchors.verticalCenter: parent.verticalCenter
            
            visible: true
            
            iconName: "settings"
            buttonSize: 32
            iconSize: 18
            
            onClicked: () => {
                Quickshell.execDetached(["dms", "ipc", "call", "settings", "openWith", "plugins"]);
            }
        }

        AiSelector {
            id: cbModelSelector
            model: availableAisModel
            maxPopupHeight: popoutHeight * 0.6

            width: parent.width - rowBottomRowActions.width - btnSettings.width - (Theme.spacingS * 2)
            textRole: "display_name"
            valueRole: "name"
            displayText: currentIndex === -1 ? "Select an AI Model..." : currentText

            function updateIndex() {
                for (var i = 0; i < availableAisModel.count; i++) {
                    if (availableAisModel.get(i).name === columnBottomSection.aiModel) {
                        currentIndex = i;
                        return;
                    }
                }
                currentIndex = -1;
            }

            Component.onCompleted: updateIndex()

            Connections {
                target: availableAisModel
                function onCountChanged() { cbModelSelector.updateIndex() }
            }

            onActivated: {
                if (pluginService) {
                    columnBottomSection.aiModel = currentValue
                    pluginService.savePluginData(pluginId, "aiModel", currentValue)
                    columnBottomSection.checkModelAvailability()
                }
            }
        }
        
        Row {
            id: rowBottomRowActions
            width: Theme.fontSizeLarge * 4 + Theme.spacingS
            height: cbModelSelector.implicitHeight

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS
            anchors.top: parent.top


            DankActionButton {
                anchors.top: parent.top
                anchors.margins: Theme.spacingXS
                
                visible: true
                
                iconName: "history_off"
                buttonSize: 32
                iconSize: 18
                
                ConfirmModal {
                    id: clearChatConfirm
                }                                

                onClicked: () => {
                    clearChatConfirm.showWithOptions({
                        title: "Clear Chat",
                        message: "Are you sure you want to clear the current chat history? This action cannot be undone.",
                        confirmText: "Clear",
                        confirmColor: Theme.error,
                        onConfirm: () => columnBottomSection.clearChat()
                    });
                }
            }

            DankActionButton {
                anchors.top: parent.top
                anchors.margins: Theme.spacingXS
                
                visible: true
                
                iconName: "push_pin"
                buttonSize: 32
                iconSize: 18

                iconColor: columnBottomSection.popoutSticky ? Theme.surfaceVariantText : Theme.surfaceText
                backgroundColor: columnBottomSection.popoutSticky ? Theme.surfaceVariant : "transparent"
                
                onClicked: () => {
                    columnBottomSection.toggleSticky()
                }
            }


        }
    }

    StyledText {
        visible: !columnBottomSection.isModelAvailable && columnBottomSection.aiModel !== "" && availableAisModel.count > 0
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
                return "⚠️ Selected model \"" + columnBottomSection.aiModel + "\" is currently not available";
            }
        }
        
        text: getText()
    }
}
