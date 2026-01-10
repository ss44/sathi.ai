import QtQuick
import "providers.js" as Providers

Item {
    id: root
    property string geminiApiKey: ""
    property string ollamaUrl: ""
    
    // signal newMessage(string text, bool isError)
    signal newModels(string modelData)

    onOllamaUrlChanged: {
        Providers.setOllamaUrl(ollamaUrl);
        Providers.getOllamaModels(processModels);
    }

    onGeminiApiKeyChanged: {
        Providers.setGeminiApiKey(geminiApiKey);
        Providers.getGeminiModels(processModels);
    }

    function processModels (models, error) {
        if (models) {
            newModels(JSON.stringify(models));
        } else {
            newModels("[]");
        }
    }

    function isModelAvailable(modelName) {
        return Providers.isModelLoaded(modelName);
    }

    function fetchModels() {
        Providers.listModels(function(models, error) {
             // We can ignore partial errors as listModels tries its best
             if (models) {
                 newModels(JSON.stringify(models), false);
             } else {
                 newModels("[]", false);
             }
        });
    }

    function sendMessage(text) {
        // No-op
    }
}
