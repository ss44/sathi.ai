import QtQuick
import "providers.js" as Providers

Item {
    id: root
    property string geminiApiKey: ""
    property string openaiApiKey: ""
    property string ollamaUrl: ""
    property string lmstudioUrl: ""
    property string anthropicApiKey: ""
    property string groqApiKey: ""
    property string openrouterApiKey: ""
    property string modalUrl: ""
    property string modalApiKey: ""

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

    onOpenaiApiKeyChanged: {
        Providers.setOpenaiApiKey(openaiApiKey);
        Providers.getOpenaiModels(processModels);
    }

    onLmstudioUrlChanged: {
        Providers.setLMStudioUrl(lmstudioUrl);
        Providers.getLMStudioModels(processModels);
    }

    onAnthropicApiKeyChanged: {
        Providers.setAnthropicApiKey(anthropicApiKey);
        Providers.getAnthropicModels(processModels);
    }

    onGroqApiKeyChanged: {
        Providers.setGroqApiKey(groqApiKey);
        Providers.getGroqModels(processModels);
    }

    onOpenrouterApiKeyChanged: {
        Providers.setOpenRouterApiKey(openrouterApiKey);
        Providers.getOpenRouterModels(processModels);
    }

    onModalUrlChanged: {
        Providers.setModalUrl(modalUrl);
        Providers.getModalModels(processModels);
    }

    onModalApiKeyChanged: {
        Providers.setModalApiKey(modalApiKey);
        if (modalUrl) {
            Providers.getModalModels(processModels);
        }
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
