import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
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
    property string resizeCorner: "right"
    property real resizeGripSize: 0

    signal processMessage(string message)
    signal clearChat()
    signal toggleSticky()
    signal checkModelAvailability()

    readonly property real resizeGripInset: Math.max(0, resizeGripSize - Theme.spacingL)
    readonly property real leftInset: resizeCorner === "left" ? resizeGripInset : 0
    readonly property real rightInset: resizeCorner === "right" ? resizeGripInset : 0

    function focusInput() {
        chatInput.forceActiveFocus();
        chatInput.cursorPosition = chatInput.length;
    }

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: Theme.spacingL
    anchors.rightMargin: Theme.spacingL
    anchors.bottomMargin: Theme.spacingXS
    visible: availableAisModel.count > 0

    spacing: Theme.spacingM
    width: parent.width

    ChatInput {
        id: chatInput
        width: parent.width
        text: columnBottomSection.pendingInputText
        onTextChanged: columnBottomSection.pendingInputText = text

        onAccepted: {
            columnBottomSection.processMessage(text);

            text = "";
            columnBottomSection.pendingInputText = "";
        }
    }

    Row {
        id: bottomModelSelectorRow
        x: columnBottomSection.leftInset
        width: parent.width - columnBottomSection.leftInset - columnBottomSection.rightInset
        height: Theme.buttonHeightXS
        spacing: Theme.spacingS

        DActionButton {
            id: btnSettings
            anchors.verticalCenter: parent.verticalCenter

            iconName: "settings"
            tooltipText: "Settings"

            onClicked: () => {
                Quickshell.execDetached(["dms", "ipc", "call", "settings", "openWith", "plugins"]);
            }
        }

        AiSelector {
            id: cbModelSelector
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - btnSettings.width - rowBottomRowActions.width - (bottomModelSelectorRow.spacing * 2)

            maxPopupHeight: popoutHeight * 0.6
            model: availableAisModel

            currentValueId: columnBottomSection.aiModel

            onCurrentValueIdChanged: {
                if (currentValueId !== columnBottomSection.aiModel && pluginService) {
                    columnBottomSection.aiModel = currentValueId;
                    pluginService.savePluginData(pluginId, "aiModel", currentValueId);
                    columnBottomSection.checkModelAvailability();
                }
            }
        }

        Row {
            id: rowBottomRowActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: bottomModelSelectorRow.spacing

            DActionButton {
                anchors.verticalCenter: parent.verticalCenter

                iconName: "history_off"
                tooltipText: "Clear chat"

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

            DActionButton {
                anchors.verticalCenter: parent.verticalCenter

                iconName: "push_pin"
                tooltipText: columnBottomSection.popoutSticky ? "Unpin popout" : "Keep popout open"

                iconColor: columnBottomSection.popoutSticky ? Theme.onPrimary : Theme.onSurfaceVariant
                backgroundColor: columnBottomSection.popoutSticky ? Theme.primary : "transparent"

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
