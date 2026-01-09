.pragma library

var history = [];
var apiKey = "";
var currentModel = "gemini-1.5-flash";
var useGrounding = false;
var systemPrompt = "";

function setApiKey(key) {
    apiKey = key;
}

function setModel(model) {
    currentModel = model;
}

function setUseGrounding(enabled) {
    useGrounding = enabled;
}

function setSystemPrompt(prompt) {
    systemPrompt = prompt;
    console.log("System prompt set to: " + systemPrompt);
    
    clearHistory();

    history.push({
        role: "user",
        parts: [{ text: prompt }]
    });    
}

function clearHistory() {
    history = [];
}

function getHistory() {
    return history;
}

function listModels(callback) {
    var xhr = new XMLHttpRequest();
    var url = "https://generativelanguage.googleapis.com/v1beta/models?key=" + apiKey;
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    var models = [];
                    if (response.models) {
                        for (var i = 0; i < response.models.length; i++) {
                            var m = response.models[i];
                            var name = m.name;
                            if (name.startsWith("models/")) {
                                name = name.substring(7);
                            }
                            var modelData = { "name": name };
                            if (m.displayName) {
                                modelData["display_name"] = m.displayName;
                            }
                            models.push(modelData);
                        }
                    }
                    callback(models, null);
                } catch (e) {
                    callback(null, "Failed to parse models: " + e.message);
                }
            } else {
                callback(null, "HTTP Error: " + xhr.status + " " + xhr.statusText);
            }
        }
    };
    
    xhr.open("GET", url);
    xhr.send();
}

function sendMessage(text, callback) {
    if (!apiKey) {
        callback(null, "API Key not set");
        return;
    }

    // Add user message to history
    history.push({
        role: "user",
        parts: [{ text: text }]
    });

    var xhr = new XMLHttpRequest();
    var url = "https://generativelanguage.googleapis.com/v1beta/models/" + currentModel + 
        (useGrounding ? ":generateContent" : "");
    
    console.log(url)
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    // Extract text from response
                    // Structure: candidates[0].content.parts[0].text
                    var responseText = "";
                    if (response.candidates && response.candidates.length > 0 &&
                        response.candidates[0].content && 
                        response.candidates[0].content.parts &&
                        response.candidates[0].content.parts.length > 0) {
                        
                        responseText = response.candidates[0].content.parts[0].text;
                        
                        // Add model response to history
                        history.push({
                            role: "model",
                            parts: [{ text: responseText }]
                        });
                        
                        callback(responseText, null);
                    } else {
                        callback(null, "Empty response from API");
                    }
                } catch (e) {
                    callback(null, "Failed to parse response: " + e.message);
                }
            } else {
                var errorMsg = "HTTP Error: " + xhr.status;
                try {
                     var errJson = JSON.parse(xhr.responseText);
                     if (errJson.error && errJson.error.message) {
                         errorMsg += " - " + errJson.error.message;
                     }
                } catch(e) {}
                callback(null, errorMsg);
            }
        }
    };
    
    var payload = {
        contents: history
    };

    xhr.open("POST", url);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("x-goog-api-key", apiKey);
    xhr.send(JSON.stringify(payload));
}
