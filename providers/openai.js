.pragma library
.import "httpClient.js" as HttpClient

var apiKey = "";
var currentModel = "";

function setApiKey(key) {
    apiKey = key;
}

function setModel(model) {
    currentModel = model;
}

function listModels(callback, config) {
    var url = (config && config.baseUrl) ? config.baseUrl + "/v1/models" : "https://api.openai.com/v1/models";
    var key = config ? config.apiKey : apiKey;
    var headers = {};
    if (key) {
        headers["Authorization"] = "Bearer " + key;
    }
    
    HttpClient.request("GET", url, function(response, error) {
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
    }, null, headers);
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

    var key = config ? config.apiKey : apiKey;
    var headers = {};
    if (key) {
        headers["Authorization"] = "Bearer " + key;
    }

    HttpClient.request("POST", url, function(response, error) {
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
    }, data, headers);
}
