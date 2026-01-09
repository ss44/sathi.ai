.pragma library

var history = [];
var baseUrl = "http://localhost:11434"; // Default
var currentModel = "llama3";
var systemPrompt = "";

function setBaseUrl(url) {
    if (url) {
        // Strip trailing slash if present
        if (url.endsWith("/")) {
            baseUrl = url.substring(0, url.length - 1);
        } else {
            baseUrl = url;
        }
    }
}

function setModel(model) {
    // Strip prefix if present (e.g. "ollama:llama3" -> "llama3")
    if (model.indexOf("ollama:") === 0) {
        currentModel = model.substring(7);
    } else {
        currentModel = model;
    }
}

function setSystemPrompt(prompt) {
    systemPrompt = prompt;
}

function clearHistory() {
    history = [];
}

function listModels(callback) {
    var xhr = new XMLHttpRequest();
    var url = baseUrl + "/api/tags";
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    var models = [];
                    if (response.models) {
                        for (var i = 0; i < response.models.length; i++) {
                            var m = response.models[i];
                            // Prefix with ollama: to distinguish
                            var modelData = { 
                                "name": "ollama:" + m.name, 
                                "display_name": m.name + " (Ollama)",
                                "provider": "ollama"
                            };
                            models.push(modelData);
                        }
                    }
                    callback(models, null);
                } catch (e) {
                    callback(null, "Failed to parse Ollama models: " + e.message);
                }
            } else {
                callback(null, "Ollama HTTP Error: " + xhr.status);
            }
        }
    };
    
    xhr.open("GET", url);
    xhr.send();
}

function sendMessage(text, callback) {
    // Add user message to history
    history.push({
        role: "user",
        content: text
    });

    var xhr = new XMLHttpRequest();
    var url = baseUrl + "/api/chat";
    
    var messages = [];
    if (systemPrompt) {
        messages.push({ role: "system", content: systemPrompt });
    }
    // Append history
    for (var i = 0; i < history.length; i++) {
        messages.push(history[i]);
    }
    
    var payload = {
        model: currentModel,
        messages: messages,
        stream: false 
    };

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    var responseText = "";
                    
                    if (response.message && response.message.content) {
                        responseText = response.message.content;
                        
                        history.push({
                            role: "assistant",
                            content: responseText
                        });
                        
                        callback(responseText, null);
                    } else {
                        callback(null, "Empty response from Ollama");
                    }
                } catch (e) {
                    callback(null, "Failed to parse Ollama response: " + e.message);
                }
            } else {
                callback(null, "Ollama HTTP Error: " + xhr.status);
            }
        }
    };
    
    xhr.open("POST", url);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.send(JSON.stringify(payload));
}
