import QtQuick
import "../providers/providers.js" as Providers
import "../providers/crypto.js" as Crypto

Item {
    id: root
    property var customProviders: []
    
    // Legacy properties for backward compatibility
    property string geminiApiKey: ""
    property string openaiApiKey: ""
    property string ollamaUrl: ""
    property string lmstudioUrl: ""
    property string anthropicApiKey: ""

    signal newModels(string modelData)
    
    property string _lastHash: ""
    
    Timer {
        id: loadTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: doLoadProviders()
    }

    onCustomProvidersChanged: loadTimer.restart()
    onGeminiApiKeyChanged: loadTimer.restart()
    onOpenaiApiKeyChanged: loadTimer.restart()
    onOllamaUrlChanged: loadTimer.restart()
    onLmstudioUrlChanged: loadTimer.restart()
    onAnthropicApiKeyChanged: loadTimer.restart()
    
    Component.onCompleted: {
        loadTimer.restart();
    }
    
    function doLoadProviders() {
        let currentHash = JSON.stringify(customProviders) + "|" + geminiApiKey + "|" + openaiApiKey + "|" + ollamaUrl + "|" + lmstudioUrl + "|" + anthropicApiKey;
        if (currentHash === _lastHash) {
            console.info("[ChatBackendSettings] Settings unchanged, skipping reload");
            return;
        }
        _lastHash = currentHash;
        
        console.info("[ChatBackendSettings] Debounced doLoadProviders triggered. Settings changed.");
        Providers.clearProviders();
        
        let hasCustom = customProviders && customProviders.length > 0;
        
        if (hasCustom) {
            console.info("[ChatBackendSettings] Loading " + customProviders.length + " custom providers");
            for (let i = 0; i < customProviders.length; i++) {
                let p = customProviders[i];
                if (!p || !p.type) continue;
                
                // Decrypt credential
                let rawCred = Crypto.decodeKey(p.credential);
                
                Providers.addCustomProvider(p.type, p.name, rawCred);
                Providers.fetchModelsForInstance(p.name, processModels);
            }
        } else {
            console.info("[ChatBackendSettings] No custom providers found, checking legacy keys");
            // Legacy loading
            if (geminiApiKey !== "") {
                Providers.addCustomProvider("gemini", "Gemini", geminiApiKey);
                Providers.fetchModelsForInstance("Gemini", processModels);
            }
            if (openaiApiKey !== "") {
                Providers.addCustomProvider("openai", "OpenAI", openaiApiKey);
                Providers.fetchModelsForInstance("OpenAI", processModels);
            }
            if (anthropicApiKey !== "") {
                Providers.addCustomProvider("anthropic", "Anthropic", anthropicApiKey);
                Providers.fetchModelsForInstance("Anthropic", processModels);
            }
            if (ollamaUrl !== "") {
                Providers.addCustomProvider("ollama", "Ollama", ollamaUrl);
                Providers.fetchModelsForInstance("Ollama", processModels);
            }
            if (lmstudioUrl !== "") {
                Providers.addCustomProvider("lmstudio", "LM Studio", lmstudioUrl);
                Providers.fetchModelsForInstance("LM Studio", processModels);
            }
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
