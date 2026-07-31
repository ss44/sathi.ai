import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io

import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import qs.Modals.Common
import "ui"

PluginComponent {
    id: root

    layerNamespacePlugin: "dank:sathi-ai"

    property var displayText: "✨"
    property bool isLoading: false
    property string aiModel: pluginData.aiModel || ""
    property bool useGrounding: true
    property string systemPrompt: pluginData.systemPrompt || "You are a helpful assistant. Answer concisely. The chat client you are running in is small so keep answers brief. For context the current date is " + (new Date()).toDateString() + "." 
    property string pendingInputText: ""
    property string resizeCorner: pluginData.resizeCorner || "right"
    property bool popoutSticky: false
    // Hack to find the PluginPopout instance since it's an internal child of PluginComponent
    // and we cannot modify PluginComponent source code.
    property Item _popoutInstance: null
    
    Timer {
        running: true
        repeat: false
        interval: 100
        onTriggered: root.findPopoutInstance()
    }

    onPopoutStickyChanged: {
        if (root._popoutInstance) {
            // Setting backgroundInteractive to false disables the mouse area in the background window,
            // effectively making the popout 'sticky' because background clicks are not caught.
            root._popoutInstance.backgroundInteractive = !root.popoutSticky
            
            // Should release exclusive focus so we can interact with other windows
            if (root.popoutSticky) {
                root._popoutInstance.customKeyboardFocus = WlrKeyboardFocus.OnDemand;
            } else {
                root._popoutInstance.customKeyboardFocus = null;
            }
        }
    }

    function findPopoutInstance() {
        if (root._popoutInstance) return;
        
        // Search through children for an object that looks like the PluginPopout
        // It should have properties like 'shouldBeVisible', 'backgroundInteractive', 'pluginContent'
        for (var i = 0; i < root.data.length; i++) {
            var child = root.data[i];
            if (child && 
                child.toString().indexOf("PluginPopout") !== -1 ||
                (child.hasOwnProperty("shouldBeVisible") && child.hasOwnProperty("backgroundInteractive"))
               ) {
                root._popoutInstance = child;

                // Prevents the popout from losing its content when hidden, which seems to be an issue with nested popouts or something related to the way PluginComponent manages its children.
                if (root._popoutInstance.contentLoader) {
                    try {
                        root._popoutInstance.contentLoader.active = true;
                        console.debug("Sathi: Forced popout content to stay active (nested)");
                    } catch (e) { console.warn(e) }
                }

                console.debug("Sathi: Found popout instance via hack");
                break;
            }
        }
    }

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
            }
        }
    }

    property ListModel chatModel: ListModel { }
    property ListModel availableAisModel: ListModel { }
    property bool isModelAvailable: true

    // When trying to access the visibility of the popout from within other functions
    // chatPopout.visible always returned false or something weird, not sure if thats a bug
    // or intended but this workaround seems to do the trick.
    QtObject {
        id: internalProps
        property bool isPopoutVisible: false
    }

    Process {
        id: hiddenNotificationProcess
        property string message: ""
        command: ["notify-send", 
            "-i", Qt.resolvedUrl('./assets/star.png').toString().replace("file://", ""), 
            "SathiAI",
            message.substring(0, 100) + (message.length > 100 ? "..." : "")
        ]
        running: false
    }

    onAvailableAisModelChanged: {
        root.checkModelAvailability();
    }

    function checkModelAvailability() {
        if (!root.aiModel) {
            root.isModelAvailable = false; // Or false if strict, but if empty usually means not set/default
            return;
        }

        root.isModelAvailable = backendSettings.isModelAvailable(root.aiModel);
        console.debug("Model availability for " + root.aiModel + ": " + root.isModelAvailable);
    }

    function showMessageAlertIfHidden(message) {
        if (!pluginData.showMessageAlerts) {
            return;
        }
        
        // For some reason we can't just check chatPopout.visible directly here?
        // So we're using internalProps as a workaround..
        if (internalProps.isPopoutVisible && !hiddenNotificationProcess.running) {
            return
        }

        console.debug("Showing hidden message notification:", message)
        hiddenNotificationProcess.message = message
        hiddenNotificationProcess.running = true
    }

    ChatBackendChat {
        id: backendChat
        geminiApiKey: pluginData.geminiApiKey || ""
        openaiApiKey: pluginData.openaiApiKey || ""
        anthropicApiKey: pluginData.anthropicApiKey || ""
        ollamaUrl: pluginData.ollamaUrl || ""
        lmstudioUrl: pluginData.lmstudioUrl || ""
        persistChatHistory: pluginData.persistChatHistory

        model: root.aiModel
        useGrounding: root.useGrounding
        systemPrompt: root.systemPrompt
        maxHistory: pluginData.maxMessageHistory || 20

        pluginId: root.pluginId
        pluginService: root.pluginService

        onNewMessage: (text, isError, metadata) => {
            root.isLoading = false;
            // Remove the thinking bubble if it exists
            if (chatModel.count > 0) {
                 var last = chatModel.get(chatModel.count - 1);
                 if (last.isThinking === true) {
                     chatModel.remove(chatModel.count - 1);
                 }
            }
            chatModel.append(createChatEntry(text, false, true, false, metadata));

            root.pruneUiHistory();
            
            root.showMessageAlertIfHidden(text);
        }

        onChatHistoryLoaded: (chatHistory) => {
            console.debug("Chat history loaded:", chatHistory);
            for (var i = 0; i < chatHistory.length; i++) {
                var message = chatHistory[i];
                chatModel.append(createChatEntry(
                    message.content,
                    message.role === "user",
                    false,
                    false,
                    message.metadata || {}
                ));
            }
            root.pruneUiHistory();
        }
    }

    ChatBackendSettings {
        id: backendSettings
        geminiApiKey: pluginData.geminiApiKey || ""
        openaiApiKey: pluginData.openaiApiKey || ""
        anthropicApiKey: pluginData.anthropicApiKey || ""
        ollamaUrl: pluginData.ollamaUrl || ""
        lmstudioUrl: pluginData.lmstudioUrl || ""

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

    function pruneUiHistory() {
        while (chatModel.count > 500) {
            chatModel.remove(0);
        }
    }

    function createChatEntry(text, isUser, shouldAnimate, isThinking, metadata) {
        return {
            "text": text,
            "isUser": isUser,
            "shouldAnimate": shouldAnimate,
            "isThinking": isThinking,
            "thinkingStartTime": isThinking ? Date.now() : 0,
            "metadata": metadata || {}
        };
    }

    function processMessage(message) {
        if (message === "") return;

        chatModel.append(createChatEntry(message, true, false, false, {}));
        root.pruneUiHistory();
        root.isLoading = true;
        
        chatModel.append(createChatEntry("", false, true, true, {}));
        backendChat.sendMessage(message);
    }

    popoutContent: chatPopout

    Component {
        id: chatPopout
        PopoutComponent {
            id: popoutColumn
            showCloseButton: false

            onVisibleChanged: {
                if (visible) {
                    columnBottomSection.focusInput();
                }

                internalProps.isPopoutVisible = visible;
            }            

            Item {
                width: parent.width
                height: root.popoutHeight - popoutColumn.headerHeight -
                               popoutColumn.detailsHeight - Theme.spacingL


                EmptyChatState {
                    isVisible: availableAisModel.count === 0
                }

                Flickable { 
                    id: flickable
                    visible: availableAisModel.count > 0
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: columnBottomSection.top
                    anchors.bottomMargin: Theme.spacingL
                    anchors.margins: Theme.spacingL
                    
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
                                thinkingStartTime: model.thinkingStartTime !== undefined ? model.thinkingStartTime : 0
                                metadata: model.metadata !== undefined ? model.metadata : ({})
                                showMessageDetails: pluginData.showMessageDetails === true
                                width: chatColumn.width - (chatColumn.padding * 2)
                                onAnimationCompleted: model.shouldAnimate = false
                            }
                        }

                    }
                }

                ChatBottomBar {
                    id: columnBottomSection
                    availableAisModel: root.availableAisModel
                    aiModel: root.aiModel
                    isModelAvailable: root.isModelAvailable
                    pendingInputText: root.pendingInputText
                    popoutSticky: root.popoutSticky
                    popoutHeight: root.popoutHeight
                    pluginId: root.pluginId
                    pluginService: root.pluginService

                    onProcessMessage: (message) => root.processMessage(message)
                    onClearChat: () => backendChat.clearChat()
                    onToggleSticky: () => root.popoutSticky = !root.popoutSticky
                    onCheckModelAvailability: () => root.checkModelAvailability()
                    onPendingInputTextChanged: root.pendingInputText = pendingInputText
                    onAiModelChanged: root.aiModel = aiModel
                }

                ResizeGrip {
                    resizeCorner: root.resizeCorner
                    popoutWidth: root.popoutWidth
                    popoutHeight: root.popoutHeight
                    pluginId: root.pluginId
                    pluginService: root.pluginService

                    onPopoutWidthChanged: root.popoutWidth = popoutWidth
                    onPopoutHeightChanged: root.popoutHeight = popoutHeight
                }
            }
        }
    }

    popoutWidth: pluginData.windowWidth || 400
    popoutHeight: pluginData.windowHeight || 500
}
