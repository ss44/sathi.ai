.pragma library
.import "openai_compatible.js" as OpenAICompatible

var baseUrl = "http://localhost:1234";
var currentModel = "";

function setBaseUrl(url) {
    if (url) {
        baseUrl = url.replace(/\/+$/, '');
    }
}

function setModel(model) {
    // Strip prefix if present (e.g. "lmstudio:model-name" -> "model-name")
    if (model.indexOf("lmstudio:") === 0) {
        currentModel = model.substring(9);
    } else {
        currentModel = model;
    }
}

function listModels(callback) {
    OpenAICompatible.listModels(baseUrl + "/v1", null, "lmstudio", null, callback);
}

function sendChat(history, systemPrompt, callback) {
    OpenAICompatible.sendChat(baseUrl + "/v1", null, currentModel, null, history, systemPrompt, callback);
}
