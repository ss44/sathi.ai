.pragma library

var apiKey = "";
var currentModel = "";

function setApiKey(key) {
    apiKey = key;
}

function setModel(model) {
    currentModel = model;
}

function request(method, url, callback, data, config) {
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
    var key = config ? config.apiKey : apiKey;
    if (key) {
        xhr.setRequestHeader("Authorization", "Bearer " + key);
    }
    xhr.setRequestHeader("Content-Type", "application/json");
    if (data) {
        xhr.send(JSON.stringify(data));
    } else {
        xhr.send();
    }
}

function listModels(callback, config) {
    var url = (config && config.baseUrl) ? config.baseUrl + "/v1/models" : "https://api.openai.com/v1/models";
    
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
                
                // Allow all models for custom endpoints or just gpt for default openai
                if ((config && config.baseUrl) || name.indexOf("gpt") !== -1 || name.indexOf("o1") !== -1 || name.indexOf("o3") !== -1) {
                     var modelData = { 
                        "name": name, 
                        "display_name": name,
                        "provider": config ? config.instanceName : "openai" 
                    };
                    models.push(modelData);
                }
            }
        }
        callback(models, null);
    }, null, config);
}

function sendChat(history, systemPrompt, callback, config) {
    var url = (config && config.baseUrl) ? config.baseUrl + "/v1/chat/completions" : "https://api.openai.com/v1/chat/completions";
    
    // Map standard history to OpenAI format
    var messages = [];
    if (systemPrompt) {
         messages.push({
            role: "system",
            content: systemPrompt
        });
    }

    for (var i = 0; i < history.length; i++) {
        var item = history[i];
         // Our internal 'model' role -> 'assistant' for openai
        var r = (item.role === 'model') ? 'assistant' : item.role;
        
        messages.push({
            role: r,
            content: item.content
        });
    }

    var data = {
        model: config ? config.model : currentModel,
        messages: messages
    };

    request("POST", url, function(response, error) {
        if (error) {
            callback(null, error);
            return;
        }

        if (response.choices && response.choices.length > 0) {
            var content = response.choices[0].message.content;
            var meta = response.usage ? { promptTokens: response.usage.prompt_tokens, completionTokens: response.usage.completion_tokens, totalTokens: response.usage.total_tokens } : {};
            callback(content, null, meta);
        } else {
            callback(null, "No response content");
        }
    }, data, config);
}
