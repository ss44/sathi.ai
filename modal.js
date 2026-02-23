.pragma library
.import "openai_compatible.js" as OpenAICompatible

var apiKey = "";
var currentModel = "";
var baseUrl = "";

function setApiKey(key) {
    apiKey = key;
}

function setBaseUrl(url) {
    if (url) {
        baseUrl = url.replace(/\/+$/, '');
    }
}

function setModel(model) {
    if (model.indexOf("modal:") === 0) {
        currentModel = model.substring(6);
    } else {
        currentModel = model;
    }
}

function listModels(callback) {
    if (!baseUrl) {
        callback([], null);
        return;
    }
    OpenAICompatible.listModels(baseUrl + "/v1", apiKey, "modal", null, callback);
}

function sendChat(history, systemPrompt, callback) {
    OpenAICompatible.sendChat(baseUrl + "/v1", apiKey, currentModel, null, history, systemPrompt, callback);
}
