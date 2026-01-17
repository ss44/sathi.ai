import QtQuick

import "providers.js" as Providers

Item {
    id: root
    
    property string geminiApiKey: ""
    property string openaiApiKey: ""
    property string ollamaUrl: ""
    property int maxHistory: 20
    
    property bool running: false
    property string model: ""
    property bool useGrounding: false
    property string systemPrompt: ""
    property bool persistChatHistory: false

    signal newMessage(string text, bool isError)
    signal chatHistoryLoaded(var chatHistory)

    // We only ever want to try and load chat once.
    QtObject {
        id: internal
        property bool tryToLoadChat: true
    }
    
    onGeminiApiKeyChanged: {
        Providers.setGeminiApiKey(geminiApiKey);
    }
    
    onOpenaiApiKeyChanged: {
        Providers.setOpenaiApiKey(openaiApiKey);
    }

    onOllamaUrlChanged: {
        Providers.setOllamaUrl(ollamaUrl);
    }
    
    onMaxHistoryChanged: {
        Providers.setMaxHistory(maxHistory);
    }

    onPersistChatHistoryChanged: {
        Providers.setPersistChatHistory(persistChatHistory);
    }

    onModelChanged: {
        console.debug("Model changed: " + model);
        Providers.setModel(model);
    }

    onUseGroundingChanged: {
        Providers.setUseGrounding(useGrounding);
    }

    onSystemPromptChanged: {
        console.log("System prompt changed: " + systemPrompt);
        Providers.setSystemPrompt(systemPrompt);
    }

    function sendMessage(text) {
        Providers.sendMessage(text, function(response, error) {
            if (error) {
                newMessage("Error: " + error, true);
            } else {
                newMessage(response, false);
            }
        });
    }

    function setPluginIdAndService(id, service) {
        if (!id || !service) {
            return;
        }

        Providers.setPluginIdAndService(id, service);

        if (persistChatHistory && internal.tryToLoadChat) {
            console.debug("Loading chat history for plugin ID:", id);
            try {
                chatHistoryLoaded(Providers.loadChatHistory());
            } catch (e) {
                console.error("Error loading chat history: " + e);
            }
        }

        // Regardless of if we loaded or not based on the persistChatHistory setting,
        // we only want to try it the once at load which is the only time
        // these variables should get set.
        internal.tryToLoadChat = false;
    }
}
