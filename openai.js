.pragma library
.import "openai_compatible.js" as OpenAICompatible

var apiKey = "";
var currentModel = "";

var BASE_URL = "https://api.openai.com/v1";

function setApiKey(key) {
    apiKey = key;
}

function setModel(model) {
    currentModel = model;
}

function listModels(callback) {
    OpenAICompatible.listModels(BASE_URL, apiKey, "openai", null, function(models, error) {
        if (error) {
            callback(null, error);
            return;
        }
        // Filter for GPT chat models
        var filtered = [];
        for (var i = 0; i < models.length; i++) {
            if (models[i].display_name.indexOf("gpt") !== -1) {
                filtered.push(models[i]);
            }
        }
        callback(filtered, null);
    });
}

function sendChat(history, systemPrompt, callback) {
    OpenAICompatible.sendChat(BASE_URL, apiKey, currentModel, null, history, systemPrompt, callback);
}
