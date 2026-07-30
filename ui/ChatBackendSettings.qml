import QtQuick
import "../providers/providers.js" as Providers

Item {
    id: root
    property string geminiApiKey: ""
    property string openaiApiKey: ""
    property string ollamaUrl: ""
    property string lmstudioUrl: ""
    property string anthropicApiKey: ""

    // signal newMessage(string text, bool isError)
    signal newModels(string modelData)

    onOllamaUrlChanged: {
        Providers.setCredential("ollama", ollamaUrl);
        Providers.fetchModels("ollama", processModels);
    }

    onGeminiApiKeyChanged: {
        Providers.setCredential("gemini", geminiApiKey);
        Providers.fetchModels("gemini", processModels);
    }

    onOpenaiApiKeyChanged: {
        Providers.setCredential("openai", openaiApiKey);
        Providers.fetchModels("openai", processModels);
    }

    onLmstudioUrlChanged: {
        Providers.setCredential("lmstudio", lmstudioUrl);
        Providers.fetchModels("lmstudio", processModels);
    }

    onAnthropicApiKeyChanged: {
        Providers.setCredential("anthropic", anthropicApiKey);
        Providers.fetchModels("anthropic", processModels);
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
