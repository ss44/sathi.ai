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
    signal clearingModels()
    
    property string _lastHash: ""
    
    Timer {
        id: loadTimer
        interval: 2000 // Increased to 2 seconds for a better debounce when typing filters or keys
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
        clearingModels();
        
        let hasCustom = customProviders && customProviders.length > 0;
        
        if (hasCustom) {
            console.info("[ChatBackendSettings] Loading " + customProviders.length + " custom providers");
            for (let i = 0; i < customProviders.length; i++) {
                let p = customProviders[i];
                if (!p || !p.type) continue;
                
                // Decrypt credential
                let rawCred = Crypto.decodeKey(p.credential);
                let pid = p.id || p.name;
                
                Providers.addCustomProvider(p.type, p.name, rawCred, p.url, p.useGrounding, pid, p.modelFilter);
                Providers.fetchModelsForInstance(pid, processModels);
            }
        } else {
            console.info("[ChatBackendSettings] No custom providers found, checking legacy keys");
            // Legacy loading
            if (geminiApiKey !== "") {
                Providers.addCustomProvider("gemini", "Gemini", geminiApiKey, null, true, "legacy_gemini");
                Providers.fetchModelsForInstance("legacy_gemini", processModels);
            }
            if (openaiApiKey !== "") {
                Providers.addCustomProvider("openai", "OpenAI", openaiApiKey, "https://api.openai.com", false, "legacy_openai");
                Providers.fetchModelsForInstance("legacy_openai", processModels);
            }
            if (anthropicApiKey !== "") {
                Providers.addCustomProvider("anthropic", "Anthropic", anthropicApiKey, null, false, "legacy_anthropic");
                Providers.fetchModelsForInstance("legacy_anthropic", processModels);
            }
            if (ollamaUrl !== "") {
                Providers.addCustomProvider("openai", "Ollama", "", ollamaUrl, false, "legacy_ollama");
                Providers.fetchModelsForInstance("legacy_ollama", processModels);
            }
            if (lmstudioUrl !== "") {
                Providers.addCustomProvider("openai", "LM Studio", "", lmstudioUrl, false, "legacy_lmstudio");
                Providers.fetchModelsForInstance("legacy_lmstudio", processModels);
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
