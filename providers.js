.pragma library
.import "gemini.js" as Gemini
.import "ollama.js" as Ollama
.import "anthropic.js" as Anthropic
.import "openai_compatible.js" as OpenAICompatible

var ollamaUrl = "";
var geminiKey = "";
var anthropicKey = "";
var loadedModels = {};
var modelKey = "";

// Centralized History
var masterHistory = []; 
var systemPrompt = "";
var maxHistory = 20;
var persistChatHistory = false;

// Required for saving and loading data.
var pluginId = "";
var pluginService = null;

// OpenAI-compatible provider presets: id -> { name, url, needsUrl, needsApiKey }
var OPENAI_PRESETS = {
    "openai":     { name: "OpenAI",      url: "https://api.openai.com/v1",     needsUrl: false, needsApiKey: true },
    "groq":       { name: "Groq",        url: "https://api.groq.com/openai/v1", needsUrl: false, needsApiKey: true },
    "openrouter": { name: "OpenRouter",   url: "https://openrouter.ai/api/v1",  needsUrl: false, needsApiKey: true },
    "lmstudio":   { name: "LM Studio",   url: "http://localhost:1234/v1",       needsUrl: true,  needsApiKey: false },
    "modal":      { name: "Modal",        url: "",                                needsUrl: true,  needsApiKey: true },
    "other":      { name: "Other",        url: "",                                needsUrl: true,  needsApiKey: true }
};

// ...

function getOpenAiPresets() {
    // Explicit order for UI consistency
    var order = ["openai", "groq", "openrouter", "lmstudio", "modal", "other"];
    var list = [];
    for (var i = 0; i < order.length; i++) {
        var key = order[i];
        if (OPENAI_PRESETS[key]) {
            var p = OPENAI_PRESETS[key];
            list.push({
                id: key,
                name: p.name,
                url: p.url,
                needsUrl: p.needsUrl,
                needsApiKey: p.needsApiKey
            });
        }
    }
    return list;
}

// Dynamic OpenAI-compatible providers configured from settings JSON.
// Each entry: { id, name, url, apiKey, currentModel, _facade }
var openaiProviders = {};

function setMaxHistory(max) {
    console.log("Setting max history to: " + max);
    maxHistory = max;
}

function setPersistChatHistory(enabled) {
    console.log("Setting persistChatHistory to: " + enabled);

    persistChatHistory = enabled;
    
    // We should clear our messages if we've been turned off and save them if we've been turned on.
    enabled ? saveChatHistory() : clearSavedChatHistory();
}

function clearSavedChatHistory() {
    if (!pluginService || !pluginId) {
        return;
    }
    
    console.log("Clearing saved chat history.");
    pluginService.savePluginData(pluginId, "chatHistory", null);
}

function clearChatHistory() {
    console.debug("Clearing in-memory chat history.");

    masterHistory = [];
    clearSavedChatHistory();
}

function setGeminiApiKey(key) {
    geminiKey = key;
    Gemini.setApiKey(key);
}

function setOllamaUrl(url) {
    ollamaUrl = url;
    Ollama.setBaseUrl(url);
}

function setAnthropicApiKey(key) {
    anthropicKey = key;
    Anthropic.setApiKey(key);
}

/**
 * Configures all OpenAI-compatible providers from a JSON string.
 * Format: [{"id":"openai","apiKey":"sk-..."}, {"id":"groq","apiKey":"gsk-..."}, {"id":"custom_1","name":"My Server","url":"http://...","apiKey":"..."}]
 * For preset ids (openai, groq, openrouter, lmstudio, modal), the URL is auto-filled from OPENAI_PRESETS.
 * For custom entries, user supplies both name and url.
 */
function setOpenAICompatibleProviders(jsonString, callback) {
    var configs;
    try {
        configs = JSON.parse(jsonString);
    } catch (e) {
        console.error("Failed to parse OpenAI providers config: " + e);
        return;
    }

    if (!Array.isArray(configs)) {
        return;
    }

    if (typeof callback !== "function") {
        callback = function() {};
    }

    // Clear previous dynamic providers and their models
    for (var oldId in openaiProviders) {
        removeProviderModels(oldId);
    }
    openaiProviders = {};

    for (var i = 0; i < configs.length; i++) {
        var config = configs[i];
        if (!config.id) continue;

        var preset = OPENAI_PRESETS[config.id];
        var providerName = preset ? preset.name : (config.name || config.id);
        var providerUrl = config.url || (preset ? preset.url : "");
        var providerApiKey = config.apiKey || "";

        if (!providerUrl) continue;

        openaiProviders[config.id] = {
            id: config.id,
            name: providerName,
            url: providerUrl,
            apiKey: providerApiKey,
            currentModel: ""
        };

        // Fetch models for this provider
        fetchOpenAIProviderModels(config.id, callback);
    }
}

function removeProviderModels(providerId) {
    var keysToRemove = [];
    for (var key in loadedModels) {
        if (loadedModels[key].provider === providerId) {
            keysToRemove.push(key);
        }
    }
    for (var i = 0; i < keysToRemove.length; i++) {
        delete loadedModels[keysToRemove[i]];
    }
}

function fetchOpenAIProviderModels(providerId, callback) {
    var config = openaiProviders[providerId];
    if (!config) return;

    console.log("Fetching models for OpenAI-compatible provider: " + providerId);
    OpenAICompatible.listModels(config.url, config.apiKey, providerId, null, function(models, error) {
        processModels(models, callback, error);
    });
}

function getOpenAICompatibleFacade(providerId) {
    var config = openaiProviders[providerId];
    if (!config) return null;

    if (!config._facade) {
        config._facade = {
            _config: config,
            setModel: function(model) {
                var prefix = config.id + ":";
                this._config.currentModel = model.indexOf(prefix) === 0
                    ? model.substring(prefix.length) : model;
            },
            sendChat: function(history, systemPrompt, callback) {
                OpenAICompatible.sendChat(
                    this._config.url, this._config.apiKey,
                    this._config.currentModel, null,
                    history, systemPrompt, callback
                );
            }
        };
    }
    return config._facade;
}

function getOllamaModels(callback) {
    console.log("Fetching Ollama models from URL: " + ollamaUrl);
    Ollama.listModels((models, error) => {
        processModels(models, callback, error);
    });
}

function getGeminiModels(callback) {
    console.log("Fetching Gemini models...");
    Gemini.listModels((models, error) => {
        processModels(models, callback, error);
    });
}

function getAnthropicModels(callback) {
    console.log("Fetching Anthropic models...");
    Anthropic.listModels((models, error) => {
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
        // Set default model to first available if none selected
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
    Gemini.setUseGrounding(enabled);
}

function setSystemPrompt(prompt) {
    systemPrompt = prompt;
    // Clearing history when prompt changes? 
    // Usually yes, if we change persona we start new chat.
    masterHistory = [];
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

    if (model.provider === "ollama") {
        return Ollama
    } else if (model.provider === "gemini") {
        return Gemini
    } else if (model.provider === "anthropic") {
        return Anthropic
    }

    // Check dynamic OpenAI-compatible providers
    var facade = getOpenAICompatibleFacade(model.provider);
    if (facade) {
        return facade;
    }

    throw new Error("Unknown provider: " + model.provider);
}

function pruneHistory() {
    if (masterHistory.length > maxHistory) {
         // Keep the first message (index 0)
         var first = masterHistory[0];
         // Keep the recent (maxHistory - 1) messages
         var recent = masterHistory.slice(-(maxHistory - 1));
         
         masterHistory = [first].concat(recent);
         console.log("History pruned. New length: " + masterHistory.length);
    }
}

function sendMessage(text, callback) {
    if (!currentModel()) {
        console.log("ModelKey: " + modelKey);
        callback(null, "No model selected");
        return;
    }
    
    // Add to history
    masterHistory.push({ role: "user", content: text });
    
    // Enforce limit
    pruneHistory();
    
    // Save history
    saveChatHistory();

    console.log("Sending chat. History length: " + masterHistory.length + ". Provider " + currentModel().provider);

    getProvider().setModel(currentModel().name);
    // Updated signature: sendChat(history, systemPrompt, callback)
    getProvider().sendChat(masterHistory, systemPrompt, function(response, error){
        if (response) {
            masterHistory.push({ role: "model", content: response });
            pruneHistory();
            saveChatHistory();
            console.log("Chat response received. Total history: " + masterHistory.length);
        }
        callback(response, error);
    });
}

/**
 * Saves the current chat history to persistent storage.
 */
function saveChatHistory() {
    if (!persistChatHistory || !pluginService || !pluginId) {
        return;
    }

    console.log("Saving chat history. Length: " + masterHistory.length);
    var chatHistory = JSON.stringify(masterHistory);

    // Save chat history
    pluginService.savePluginData(pluginId, "chatHistory", chatHistory);
}

/**
 * Loads previously saved chat history from persistent storage.
 */
function loadChatHistory() {
    console.debug("Attempting to load chat history.");
    if (!persistChatHistory || !pluginService || !pluginId) {
        return [];
    }

    if (masterHistory.length > 0) {
        console.warn("Chat history already loaded, skipping reload.");
        return masterHistory;
    }

    var chatHistory = pluginService.loadPluginData(pluginId, "chatHistory");
    
    if (chatHistory) {
        try {
            masterHistory = JSON.parse(chatHistory);
            console.debug("Chat history loaded. Length: " + masterHistory.length);
        } catch (e) {
            console.error("Error parsing chat history: " + e);
            masterHistory = [];
        }
    }

    return masterHistory;
}

function setPluginId(id) {
    pluginId = id;
}

function setPluginService(service) {
    pluginService = service;
}

function isModelLoaded(modelName) {
    return loadedModels.hasOwnProperty(modelName);
}