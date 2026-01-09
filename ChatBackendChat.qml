import QtQuick
import "providers.js" as Providers

Item {
    id: root

    property string apiKey: ""
    property string ollamaUrl: ""
    
    property bool running: false
    property string model: ""
    property bool useGrounding: false
    property string systemPrompt: ""

    signal newMessage(string text, bool isError)

    onApiKeyChanged: {
        Providers.setApiKey(apiKey);
    }
    
    onOllamaUrlChanged: {
        Providers.setOllamaUrl(ollamaUrl);
    }
    
    onModelChanged: {
        Providers.setModel(model);
    }

    onUseGroundingChanged: {
        Providers.setUseGrounding(useGrounding);
    }

    onSystemPromptChanged: {
        Providers.setSystemPrompt(systemPrompt);
    }

    onRunningChanged: {
        // No-op or init
        if (running) {
             if (apiKey) Providers.setApiKey(apiKey);
             if (ollamaUrl) Providers.setOllamaUrl(ollamaUrl);
             
             Providers.setModel(model);
             Providers.setUseGrounding(useGrounding);
             Providers.setSystemPrompt(systemPrompt);
        }
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
}
