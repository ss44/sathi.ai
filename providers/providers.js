.pragma library
.import "gemini.js" as Gemini
.import "ollama.js" as Ollama
.import "openai.js" as OpenAI
.import "lmstudio.js" as LMStudio
.import "anthropic.js" as Anthropic
.import "../chatHistory.js" as ChatHistory

var ProviderRegistry = {
    "gemini": Gemini,
    "ollama": Ollama,
    "openai": OpenAI,
    "lmstudio": LMStudio,
    "anthropic": Anthropic
};

var loadedModels = {};
var modelKey = "";
var systemPrompt = "";

function setMaxHistory(max) {
    ChatHistory.setMaxHistory(max);
}

function setPersistChatHistory(enabled) {
    ChatHistory.setPersistChatHistory(enabled);
}

function clearSavedChatHistory() {
    ChatHistory.clearSavedChatHistory();
}

function clearChatHistory() {
    ChatHistory.clearChatHistory();
}

function setPluginId(id) {
    ChatHistory.setPluginId(id);
}

function setPluginService(service) {
    ChatHistory.setPluginService(service);
}

function saveChatHistory() {
    ChatHistory.saveChatHistory();
}

function loadChatHistory() {
    return ChatHistory.loadChatHistory();
}

function setCredential(providerName, credential) {
    var provider = ProviderRegistry[providerName];
    if (!provider) return;
    if (providerName === 'ollama' || providerName === 'lmstudio') {
        provider.setBaseUrl(credential);
    } else {
        provider.setApiKey(credential);
    }
}

function fetchModels(providerName, callback) {
    var provider = ProviderRegistry[providerName];
    if (!provider) return;
    console.log("Fetching models for " + providerName + "...");
    provider.listModels((models, error) => {
        processModels(models, callback, error);
    });
}

function setModel(model) {
    console.log("Setting current model to: " + model);
    modelKey = model;
}

function currentModel() {
    return loadedModels[modelKey];
}

function processModels(models, callback, error) {
    if (error) {
        callback(null, error);
        return;
    }

    if (models && models.length > 0) {
        if (modelKey === "") {
            setModel(models[0].name);
        }

        for (var i = 0; i < models.length; i++) {
            loadedModels[models[i].name] = models[i];
        }

        callback(models, null);
    } else {
        callback([], null);
    }
}

function setUseGrounding(enabled) {
    ProviderRegistry["gemini"].setUseGrounding(enabled);
}

function setSystemPrompt(prompt) {
    systemPrompt = prompt;
    ChatHistory.setHistory([]);
}

function listModels(callback) {
    var modelsList = [];
    for (var key in loadedModels) {
        modelsList.push(loadedModels[key]);
    }
    callback(modelsList);
}

function getProvider() {
    var model = currentModel();
    if (!model) {
        throw new Error("No model selected");
    }

    var provider = ProviderRegistry[model.provider];
    if (provider) {
        return provider;
    }

    throw new Error("Unknown provider: " + model.provider);
}


var modelPricing = {
    "gpt-4o": { input: 5.0, output: 15.0 },
    "gpt-4o-mini": { input: 0.15, output: 0.60 },
    "gpt-4-turbo": { input: 10.0, output: 30.0 },
    "gpt-3.5-turbo": { input: 0.50, output: 1.50 },
    "claude-3-5-sonnet": { input: 3.0, output: 15.0 },
    "claude-3-opus": { input: 15.0, output: 75.0 },
    "claude-3-haiku": { input: 0.25, output: 1.25 },
    "gemini-1.5-pro": { input: 3.50, output: 10.50 },
    "gemini-1.5-flash": { input: 0.35, output: 1.05 }
};

function calculateCost(modelName, promptTokens, completionTokens) {
    if (!promptTokens && !completionTokens) return 0;
    
    // Default to 0 for local/unknown models
    var cost = 0;
    
    // Simple substring matching for pricing
    var inputPrice = 0; // per 1M tokens
    var outputPrice = 0; // per 1M tokens
    
    var lowercaseModel = modelName.toLowerCase();
    
    for (var key in modelPricing) {
        if (lowercaseModel.indexOf(key) !== -1) {
            inputPrice = modelPricing[key].input;
            outputPrice = modelPricing[key].output;
            break;
        }
    }
    
    if (inputPrice > 0 || outputPrice > 0) {
        cost = ((promptTokens || 0) * (inputPrice / 1000000)) + ((completionTokens || 0) * (outputPrice / 1000000));
    }
    return cost;
}

function sendMessage(text, callback) {
    if (!currentModel()) {
        console.log("ModelKey: " + modelKey);
        callback(null, "No model selected");
        return;
    }
    
    ChatHistory.addMessage("user", text);

    console.log("Sending chat. History length: " + ChatHistory.getHistory().length + ". Provider " + currentModel().provider);

    getProvider().setModel(currentModel().name);
    getProvider().sendChat(ChatHistory.getHistory(), systemPrompt, function(response, error, metadata){
        if (response) {
            
            if (metadata && currentModel()) {
                var c = calculateCost(currentModel().name, metadata.promptTokens, metadata.completionTokens);
                if (c > 0) {
                    metadata.estimatedCost = c;
                }
            }
            ChatHistory.addMessage("model", response, metadata);
            console.log("Chat response received. Total history: " + ChatHistory.getHistory().length);
        }
        callback(response, error, metadata);
    });
}

function isModelLoaded(modelName) {
    return loadedModels.hasOwnProperty(modelName);
}
