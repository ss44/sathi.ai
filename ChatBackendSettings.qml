import QtQuick
import "gemini.js" as Gemini

Item {
    id: root
    property string apiKey: ""
    property bool running: false
    
    signal newMessage(string text, bool isError)

    onApiKeyChanged: {
        Gemini.setApiKey(apiKey);
    }

    onRunningChanged: {
        if (running && apiKey) {
            Gemini.setApiKey(apiKey);
            fetchModels();
        }
    }
    
    function fetchModels() {
        Gemini.listModels(function(models, error) {
            if (error) {
                console.warn("Error listing models: " + error);
                // Send empty list or handle error gracefully
                newMessage("[]", true);
            } else {
                newMessage(JSON.stringify(models), false);
            }
        });
    }

    function sendMessage(text) {
        // No-op
    }
}
