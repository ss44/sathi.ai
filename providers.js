.pragma library
.import "gemini.js" as Gemini
.import "ollama.js" as Ollama

var currentModel = "";
var ollamaUrl = "";
var geminiKey = "";

function setApiKey(key) {
    geminiKey = key;
    Gemini.setApiKey(key);
}

function setOllamaUrl(url) {
    ollamaUrl = url;
    Ollama.setBaseUrl(url);
}

function setModel(model) {
    currentModel = model;
    Gemini.setModel(model);
    Ollama.setModel(model);
}

function setUseGrounding(enabled) {
    Gemini.setUseGrounding(enabled);
}

function setSystemPrompt(prompt) {
    Gemini.setSystemPrompt(prompt);
    Ollama.setSystemPrompt(prompt);
}

function listModels(callback) {
    var allModels = [];
    var pending = 0;
    var hasRun = false;

    function checkDone() {
        if (pending === 0) {
            callback(allModels, null);
        }
    }
    
    // We defer execution slightly to allow both checks to register pending
    // although JS is single threaded so synchronous blocks run to completion.
    
    if (geminiKey) {
        pending++;
        Gemini.listModels(function(models, error) {
            pending--;
            if (models) {
                // Add provider tag if missing
                for(var i=0; i<models.length; i++) {
                    if (!models[i].provider) models[i].provider = "gemini";
                }
                allModels = allModels.concat(models);
            } else {
                 console.warn("Provider Gemini list error: " + error);
            }
            checkDone();
        });
    }

    if (ollamaUrl) {
         pending++;
         Ollama.listModels(function(models, error) {
             pending--;
             if (models) {
                 allModels = allModels.concat(models);
             } else {
                 console.warn("Provider Ollama list error: " + error);
             }
             checkDone();
         });
    }

    if (pending === 0) {
        callback([], null);
    }
}

function sendMessage(text, callback) {
    if (currentModel.indexOf("ollama:") === 0) {
        if (!ollamaUrl) {
             callback(null, "Ollama URL not configured");
             return;
        }
        Ollama.sendMessage(text, callback);
    } else {
        if (!geminiKey) {
            callback(null, "Gemini API Key missing");
            return;
        }
        Gemini.sendMessage(text, callback);
    }
}
