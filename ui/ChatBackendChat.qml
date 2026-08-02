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

    function sendMessage(text) {
        Providers.sendMessage(text, function(response, error, metadata) {
            if (error) {
                newMessage("Error: " + error, true, {});
            } else {
                newMessage(response, false, metadata);
            }
        });
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
