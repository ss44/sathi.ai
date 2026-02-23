.pragma library
.import "openai_compatible.js" as OpenAICompatible

var apiKey = "";
var currentModel = "";

var BASE_URL = "https://api.groq.com/openai/v1";

function setApiKey(key) {
    apiKey = key;
}

function setModel(model) {
    if (model.indexOf("groq:") === 0) {
        currentModel = model.substring(5);
    } else {
        currentModel = model;
    }
}

function listModels(callback) {
    OpenAICompatible.listModels(BASE_URL, apiKey, "groq", null, callback);
}

function sendChat(history, systemPrompt, callback) {
    OpenAICompatible.sendChat(BASE_URL, apiKey, currentModel, null, history, systemPrompt, callback);
}
