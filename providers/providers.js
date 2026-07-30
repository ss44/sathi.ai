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

function sendMessage(text, callback) {
    if (!currentModel()) {
        console.log("ModelKey: " + modelKey);
        callback(null, "No model selected");
        return;
    }
    
    ChatHistory.addMessage("user", text);

    console.log("Sending chat. History length: " + ChatHistory.getHistory().length + ". Provider " + currentModel().provider);

    getProvider().setModel(currentModel().name);
    getProvider().sendChat(ChatHistory.getHistory(), systemPrompt, function(response, error){
        if (response) {
            ChatHistory.addMessage("model", response);
            console.log("Chat response received. Total history: " + ChatHistory.getHistory().length);
        }
        callback(response, error);
    });
}

function isModelLoaded(modelName) {
    return loadedModels.hasOwnProperty(modelName);
}
