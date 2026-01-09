import QtQuick
import "gemini.js" as Gemini

Item {
    id: root

    property string apiKey: ""
    property bool running: false
    property string model: ""
    property bool useGrounding: false
    property string systemPrompt: ""

    signal newMessage(string text, bool isError)

    onApiKeyChanged: {
        Gemini.setApiKey(apiKey);
    }
    
    onModelChanged: {
        Gemini.setModel(model);
    }

    onUseGroundingChanged: {
        Gemini.setUseGrounding(useGrounding);
    }

    onSystemPromptChanged: {
        Gemini.setSystemPrompt(systemPrompt);
    }

    onRunningChanged: {
        // No-op or init
        if (running && apiKey) {
             Gemini.setApiKey(apiKey);
             Gemini.setModel(model);
             Gemini.setUseGrounding(useGrounding);
             Gemini.setSystemPrompt(systemPrompt);
        }
    }

    function sendMessage(text) {
        if (!apiKey) {
            newMessage("Error: API Key is missing.", true);
            return;
        }
        
        Gemini.sendMessage(text, function(response, error) {
             if (error) {
                 newMessage("Error: " + error, true);
             } else {
                 newMessage(response, false);
             }
        });
    }
}
