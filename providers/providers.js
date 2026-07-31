.pragma library
.import "gemini.js" as Gemini
.import "openai.js" as OpenAI
.import "anthropic.js" as Anthropic
.import "../chatHistory.js" as ChatHistory

var ProviderRegistry = {
    "gemini": Gemini,
    "openai": OpenAI,
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

function addCustomProvider(type, name, credential, url, useGrounding, id) {
    var pid = id || name;
    console.info("[Providers] Adding custom provider instance: '" + name + "' (id: " + pid + ") of type: '" + type + "' (credential length: " + (credential ? credential.length : 0) + ")");
    customProviderInstances[pid] = {
        id: pid,
        type: type,
        name: name,
        credential: credential,
        url: url,
        useGrounding: useGrounding
    };
}

function fetchModelsForInstance(instanceId, callback) {
    console.info("[Providers] fetchModelsForInstance called for: " + instanceId);
    var instance = customProviderInstances[instanceId];
    if (!instance) {
        console.error("[Providers] Error: Instance not found: " + instanceId);
        return;
    }
    
    var provider = ProviderRegistry[instance.type];
    if (!provider) {
        console.error("[Providers] Error: Unknown provider type: " + instance.type);
        return;
    }
    
    // Set credential synchronously before calling listModels
    if (instance.type !== 'openai') {
        console.info("[Providers] Setting API key for " + instance.type + " instance " + instance.name);
        provider.setApiKey(instance.credential);
    }
    
    console.info("[Providers] Calling listModels on provider: " + instance.type);
    
    var cb = (models, error) => {
        if (error) {
            console.error("[Providers] Error fetching models for " + instance.name + ": " + error);
            callback(null, error);
            return;
        }
        
        console.info("[Providers] Fetched " + (models ? models.length : 0) + " models for " + instance.name);
        if (models && models.length > 0) {
            for (var i = 0; i < models.length; i++) {
                models[i].provider = instanceId;
                models[i].providerName = instance.name;
                // Avoid model name collisions between different provider instances
                // by using a unique internal ID, but preserving the original name for the API call
                models[i].id = instanceId + "|" + models[i].name;
                loadedModels[models[i].id] = models[i];
            }
            if (modelKey === "") {
                console.info("[Providers] Setting default model to " + models[0].id);
                setModel(models[0].id);
            }
            console.info("[Providers] Currently " + Object.keys(loadedModels).length + " total loaded models across all providers");
            callback(models, null);
        } else {
            callback([], null);
        }
    };
    
    if (instance.type === 'openai') {
        provider.listModels(cb, { baseUrl: instance.url, apiKey: instance.credential, instanceName: instance.name });
    } else {
        provider.listModels(cb);
    }
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
    
    var cb = function(response, error, metadata){
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
    };

    // Set credential and model synchronously before calling sendChat
    if (instance.type === 'openai') {
        provider.setModel(cModel.name);
        console.info("[Providers] Calling sendChat on provider " + instance.type);
        provider.sendChat(ChatHistory.getHistory(), systemPrompt, cb, {
            baseUrl: instance.url,
            apiKey: instance.credential,
            model: cModel.name
        });
    } else if (instance.type === 'gemini') {
        provider.setModel(cModel.name);
        console.info("[Providers] Calling sendChat on provider " + instance.type);
        provider.sendChat(ChatHistory.getHistory(), systemPrompt, cb, {
            credential: instance.credential,
            useGrounding: instance.useGrounding,
            model: cModel.name
        });
    } else {
        provider.setApiKey(instance.credential);
        provider.setModel(cModel.name);
        console.info("[Providers] Calling sendChat on provider " + instance.type);
        provider.sendChat(ChatHistory.getHistory(), systemPrompt, cb);
    }
}

function isModelLoaded(modelName) {
    return loadedModels.hasOwnProperty(modelName);
}

