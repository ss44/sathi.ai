import QtQuick
import "providers.js" as Providers

Item {
    id: root

    property string geminiApiKey: ""
    property string openaiApiKey: ""
    property string ollamaUrl: ""
    
    property bool running: false
    property string model: ""
    property bool useGrounding: false
    property string systemPrompt: ""

    signal newMessage(string text, bool isError)

    onGeminiApiKeyChanged: {
        Providers.setGeminiApiKey(geminiApiKey);
    }
    
    onOpenaiApiKeyChanged: {
        Providers.setOpenaiApiKey(openaiApiKey);
    }

    onOllamaUrlChanged: {
        Providers.setOllamaUrl(ollamaUrl);
    }
    
    onModelChanged: {
        console.log("Model changed: " + model);
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
}
