import QtQuick
import "providers.js" as Providers

Item {
    id: root
    property string apiKey: ""
    property string ollamaUrl: ""
    property bool running: false
    
    signal newMessage(string text, bool isError)

    onApiKeyChanged: {
        Providers.setApiKey(apiKey);
    }
    
    onOllamaUrlChanged: {
        Providers.setOllamaUrl(ollamaUrl);
    }

    onRunningChanged: {
        if (running) {
             if (apiKey) Providers.setApiKey(apiKey);
             if (ollamaUrl) Providers.setOllamaUrl(ollamaUrl);
             fetchModels();
        }
    }
    
    function fetchModels() {
        Providers.listModels(function(models, error) {
             // We can ignore partial errors as listModels tries its best
             if (models) {
                 newMessage(JSON.stringify(models), false);
             } else {
                 newMessage("[]", false);
             }
        });
    }

    function sendMessage(text) {
        // No-op
    }
}
