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

function listModels(callback) {
    var url = "https://api.anthropic.com/v1/models";
    var headers = {
        "anthropic-version": "2023-06-01"
    };
    if (apiKey) {
        headers["x-api-key"] = apiKey;
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
                var modelData = { 
                    "name": m.id, 
                    "display_name": m.display_name || m.id,
                    "provider": "anthropic" 
                };
                models.push(modelData);
            }
        }
            callback(models, null);
    }, null, headers);
}

function sendChat(history, systemPrompt, callback) {
    var url = "https://api.anthropic.com/v1/messages";
    
    // Map standard history to Anthropic format
    var messages = [];
    
    for (var i = 0; i < history.length; i++) {
        var item = history[i];
        // Our internal 'model' role -> 'assistant' for anthropic
        var r = (item.role === 'model') ? 'assistant' : item.role;
        
        messages.push({
            role: r,
            content: item.content
        });
    }

    var data = {
        model: currentModel,
        max_tokens: 4096,
        messages: messages
    };
    
    // Add system prompt if provided
    if (systemPrompt) {
        data.system = systemPrompt;
    }
    
    var headers = {
        "anthropic-version": "2023-06-01"
    };
    if (apiKey) {
        headers["x-api-key"] = apiKey;
    }

    HttpClient.request("POST", url, function(response, error) {
        if (error) {
            callback(null, error);
            return;
        }

        if (response.content && response.content.length > 0) {
            var content = response.content[0].text;
            var meta = response.usage ? { promptTokens: response.usage.input_tokens, completionTokens: response.usage.output_tokens, totalTokens: response.usage.input_tokens + response.usage.output_tokens } : {};
            callback(content, null, meta);
        } else {
            callback(null, "No response content");
        }
    }, data, headers);
}
