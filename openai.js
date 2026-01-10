.pragma library

var history = [];
var apiKey = "";
var currentModel = "gpt-3.5-turbo";
var systemPrompt = "";

function setApiKey(key) {
    apiKey = key;
}

function setModel(model) {
    currentModel = model;
}

function setSystemPrompt(prompt) {
    systemPrompt = prompt;
    // Don't clear history on system prompt change for OpenAI, just update the system message
    // actually, for consistency with Gemini implementation we might clear, 
    // but usually system prompt is just the first message.
    
    // Check if first message is system, if so replace it
    if (history.length > 0 && history[0].role === "system") {
        history[0].content = prompt;
    } else {
        // If we want consistency with gemini.js which clears history:
        clearHistory();
        if (prompt) {
            history.push({
                role: "system",
                content: prompt
            });
        }
    }
}

function clearHistory() {
    history = [];
    if (systemPrompt) {
        history.push({
            role: "system",
            content: systemPrompt
        });
    }
}

function getHistory() {
    return history;
}

function request(method, url, callback, data) {
    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                try {
                    var response = JSON.parse(xhr.responseText);
                    callback(response, null);
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
    xhr.open(method, url);
    if (apiKey) {
        xhr.setRequestHeader("Authorization", "Bearer " + apiKey);
    }
    xhr.setRequestHeader("Content-Type", "application/json");
    if (data) {
        xhr.send(JSON.stringify(data));
    } else {
        xhr.send();
    }
}

function listModels(callback) {
    var url = "https://api.openai.com/v1/models";
    
    request("GET", url, function(response, error) {
        if (error) {
            callback(null, error);
            return;
        }

        var models = [];
        if (response.data) {
            for (var i = 0; i < response.data.length; i++) {
                var m = response.data[i];
                var name = m.id;
                
                // Filter for chat models usually, but let's just list gpt models
                if (name.indexOf("gpt") !== -1) {
                     var modelData = { 
                        "name": name, 
                        "display_name": name,
                        "provider": "openai" 
                    };
                    models.push(modelData);
                }
            }
        }
        callback(models, null);
    });
}

function sendMessage(text, callback) {
    var url = "https://api.openai.com/v1/chat/completions";
    
    if (!history.length && systemPrompt) {
         history.push({
            role: "system",
            content: systemPrompt
        });
    }

    history.push({
        role: "user",
        content: text
    });

    var data = {
        model: currentModel,
        messages: history
    };

    request("POST", url, function(response, error) {
        if (error) {
            // Remove the failed user message? 
            // For now let's leave it or maybe pop it.
            callback(null, error);
            return;
        }

        if (response.choices && response.choices.length > 0) {
            var content = response.choices[0].message.content;
            history.push({
                role: "assistant",
                content: content
            });
            callback(content, null);
        } else {
            callback(null, "No response content");
        }
    }, data);
}
