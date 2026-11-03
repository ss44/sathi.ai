import QtQuick

import "../providers/providers.js" as Providers
import "../chatHistory.js" as ChatHistory

Item {
    id: root

    property int maxHistory: 20

    property bool running: false
    property string model: ""
    property bool useGrounding: false
    property string systemPrompt: ""

    property bool persistChatHistory: false
    property string pluginId
    property var pluginService

    property bool smartContext: false
    property string fastModel: ""

    signal newMessage(string text, bool isError, var metadata)
    signal chatHistoryLoaded(var chatHistory)

    // We only ever want to try and load chat once.
    QtObject {
        id: internal
        property bool tryToLoadChat: true
    }

    onMaxHistoryChanged: {
        ChatHistory.setMaxHistory(maxHistory);
    }

    onPersistChatHistoryChanged: {
        ChatHistory.setPersistChatHistory(persistChatHistory);
        tryToLoadChatHistory();       
    }

    onSmartContextChanged: {
        Providers.setSmartContext(smartContext);
    }

    onFastModelChanged: {
        Providers.setFastModel(fastModel);
    }

    onModelChanged: {
        if (model !== "") {
            console.debug("Model changed: " + model);
            Providers.setModel(model);
        }
    }

    onUseGroundingChanged: {
        Providers.setUseGrounding(useGrounding);
    }

    onSystemPromptChanged: {
        console.log("System prompt changed: " + systemPrompt);
        Providers.setSystemPrompt(systemPrompt);
    }

    property var currentRequest: null
    property int currentRequestId: 0

    function abortCurrentRequest() {
        root.currentRequestId = root.currentRequestId + 1;
        var req = root.currentRequest;
        root.currentRequest = null;
        if (req && typeof req.abort === 'function') {
            try {
                req.abort();
            } catch (e) {
                console.error("Error aborting XHR: " + e);
            }
        }
    }

    function sendMessage(text) {
        root.currentRequestId = root.currentRequestId + 1;
        var reqId = root.currentRequestId;
        var req = Providers.sendMessage(text, function(response, error, metadata) {
            if (reqId !== root.currentRequestId) {
                console.debug("Ignoring response from aborted request. reqId: " + reqId + " current: " + root.currentRequestId);
                return;
            }
            root.currentRequest = null;
            if (error) {
                newMessage("Error: " + error, true, {});
            } else {
                // Smart context orchestration persists both turns itself; adding the
                // model message here would duplicate it in history.
                if (!metadata || metadata.smartContext !== true) {
                    ChatHistory.addMessage("model", response, metadata);
                }
                newMessage(response, false, metadata);
            }
        });
        root.currentRequest = req;
    }

    onPluginIdChanged: {
        ChatHistory.setPluginId(pluginId);
        tryToLoadChatHistory()
    }

    onPluginServiceChanged: {
        ChatHistory.setPluginService(pluginService);
        tryToLoadChatHistory()
    }

    /**
     * Attempt to load chat history if we have access to:
     *  - pluginId is set.
     *  - pluginService is set
     *  - persistChatHistory is enabled
     *  - and we haven't attempted to already load chat history previously.
     **/
    
    function tryToLoadChatHistory() {
        console.debug("Trying to load chat history...", pluginId, pluginService, persistChatHistory, internal.tryToLoadChat);

        if (!pluginId || !pluginService || !persistChatHistory || !internal.tryToLoadChat) {
            return;
        }

        try {
            chatHistoryLoaded(ChatHistory.loadChatHistory());
        } catch (e) {
            console.error("Error loading chat history: " + e);
        }

        // Regardless of if we loaded or not based on the persistChatHistory setting,
        // we only want to try it the once at load which is the only time
        // these variables should get set.
        internal.tryToLoadChat = false;
    }

    function clearChat() {
        console.debug("Clearing chat history as requested.");
        ChatHistory.clearChatHistory();
        chatModel.clear();
    }
}
