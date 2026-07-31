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

// customProviderInstances stores { type, name, credential }
var customProviderInstances = {};

function clearProviders() {
    console.info("[Providers] Clearing all providers and loaded models");
    customProviderInstances = {};
    loadedModels = {};
}

function addCustomProvider(type, name, credential) {
    console.info("[Providers] Adding custom provider instance: '" + name + "' of type: '" + type + "' (credential length: " + (credential ? credential.length : 0) + ")");
    customProviderInstances[name] = {
        type: type,
        name: name,
        credential: credential
    };
}

function fetchModelsForInstance(instanceName, callback) {
    console.info("[Providers] fetchModelsForInstance called for: " + instanceName);
    var instance = customProviderInstances[instanceName];
    if (!instance) {
        console.error("[Providers] Error: Instance not found: " + instanceName);
        return;
    }
    
    var provider = ProviderRegistry[instance.type];
    if (!provider) {
        console.error("[Providers] Error: Unknown provider type: " + instance.type);
        return;
    }
    
    // Set credential synchronously before calling listModels
    if (instance.type === 'ollama' || instance.type === 'lmstudio') {
        console.info("[Providers] Setting base URL for " + instance.type + " instance " + instanceName + " to: " + instance.credential);
        provider.setBaseUrl(instance.credential);
    } else {
        console.info("[Providers] Setting API key for " + instance.type + " instance " + instanceName);
        provider.setApiKey(instance.credential);
    }
    
    console.info("[Providers] Calling listModels on provider: " + instance.type);
    provider.listModels((models, error) => {
        if (error) {
            console.error("[Providers] Error fetching models for " + instanceName + ": " + error);
            callback(null, error);
            return;
        }
        
        console.info("[Providers] Fetched " + (models ? models.length : 0) + " models for " + instanceName);
        if (models && models.length > 0) {
            for (var i = 0; i < models.length; i++) {
                // Rename provider to instanceName so we can route it back
                models[i].provider = instanceName;
                loadedModels[models[i].name] = models[i];
            }
            if (modelKey === "") {
                console.info("[Providers] Setting default model to " + models[0].name);
                setModel(models[0].name);
            }
            console.info("[Providers] Currently " + Object.keys(loadedModels).length + " total loaded models across all providers");
            callback(models, null);
        } else {
            callback([], null);
        }
    });
}

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

function setModel(model) {
    if (!model) return;
    console.info("[Providers] Setting current model to: " + model);
    modelKey = model;
}

function currentModel() {
    console.info("[Providers] currentModel requested. current modelKey is: '" + modelKey + "'");
    var cModel = loadedModels[modelKey];
    
    // Fallback if modelKey is invalid but we have loaded models
    if (!cModel && Object.keys(loadedModels).length > 0) {
        var firstKey = Object.keys(loadedModels)[0];
        console.info("[Providers] currentModel: modelKey '" + modelKey + "' not found, falling back to '" + firstKey + "'");
        modelKey = firstKey;
        cModel = loadedModels[modelKey];
    }
    
    if (cModel) {
        console.info("[Providers] currentModel returning model: " + cModel.name + " (" + cModel.provider + ")");
    } else {
        console.info("[Providers] currentModel returning null. Total loaded models: " + Object.keys(loadedModels).length);
    }
    
    return cModel;
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
    console.info("[Providers] listModels returning " + modelsList.length + " models");
    callback(modelsList);
}

function getProvider() {
    var model = currentModel();
    if (!model) {
        console.error("[Providers] getProvider: No model selected");
        throw new Error("No model selected");
    }

    console.info("[Providers] getProvider: Current model is " + model.name + ", provider instance is " + model.provider);
    var instance = customProviderInstances[model.provider];
    if (instance) {
        console.info("[Providers] getProvider: Found instance type " + instance.type);
        return ProviderRegistry[instance.type];
    }

    console.error("[Providers] getProvider: Unknown provider instance: " + model.provider);
    throw new Error("Unknown provider instance: " + model.provider);
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
    
    var cost = 0;
    var inputPrice = 0;
    var outputPrice = 0;
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
    console.info("[Providers] sendMessage called with text: " + text.substring(0, 20) + "...");
    
    var cModel = currentModel();
    if (!cModel) {
        console.error("[Providers] sendMessage: No current model. ModelKey: " + modelKey);
        callback(null, "No model selected");
        return;
    }
    
    ChatHistory.addMessage("user", text);

    console.info("[Providers] Sending chat. Provider instance: " + cModel.provider + ", Model name: " + cModel.name);

    var provider;
    try {
        provider = getProvider();
    } catch (e) {
        console.error("[Providers] Error getting provider: " + e.message);
        callback(null, "Provider error: " + e.message);
        return;
    }
    
    var instance = customProviderInstances[cModel.provider];
    if (!instance) {
        console.error("[Providers] Instance not found for provider: " + cModel.provider);
        callback(null, "Instance not found");
        return;
    }
    
    console.info("[Providers] Preparing provider credential. Type: " + instance.type);
    // Set credential and model synchronously before calling sendChat
    if (instance.type === 'ollama' || instance.type === 'lmstudio') {
        provider.setBaseUrl(instance.credential);
    } else {
        provider.setApiKey(instance.credential);
    }
    provider.setModel(cModel.name);
    
    console.info("[Providers] Calling sendChat on provider " + instance.type);
    provider.sendChat(ChatHistory.getHistory(), systemPrompt, function(response, error, metadata){
        if (error) {
            console.error("[Providers] sendChat returned error: " + error);
        }
        if (response) {
            console.info("[Providers] sendChat returned response successfully");
            if (metadata && currentModel()) {
                var c = calculateCost(currentModel().name, metadata.promptTokens, metadata.completionTokens);
                if (c > 0) {
                    metadata.estimatedCost = c;
                }
            }
            ChatHistory.addMessage("model", response, metadata);
        } else if (!error) {
            console.warn("[Providers] sendChat returned neither response nor error");
        }
        callback(response, error, metadata);
    });
}

function isModelLoaded(modelName) {
    return loadedModels.hasOwnProperty(modelName);
}

