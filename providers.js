.pragma library
.import "gemini.js" as Gemini
.import "ollama.js" as Ollama

var ollamaUrl = "";
var geminiKey = "";
var loadedModels = {};
var modelKey = "";

function setGeminiApiKey(key) {
    geminiKey = key;
    Gemini.setApiKey(key);
}

function setOllamaUrl(url) {
    ollamaUrl = url;
    Ollama.setBaseUrl(url);
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
    Ollama.setSystemPrompt(prompt);
    Gemini.setSystemPrompt(prompt);
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
    }
    
    throw new Error("Unknown provider: " + model.provider);
}

function sendMessage(text, callback) {
    if (!currentModel()) {
        console.log("ModelKey: " + modelKey);
        callback(null, "No model selected");
        return;
    }

    getProvider().setModel(currentModel().name);
    getProvider().sendMessage(text, callback);
}

function isModelLoaded(modelName) {
    return loadedModels.hasOwnProperty(modelName);
}