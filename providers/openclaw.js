.pragma library
.import "httpClient.js" as HttpClient

function listModels(callback, config) {
    var url = (config && config.baseUrl) ? config.baseUrl + "/v1/agents" : "http://localhost:18789/v1/agents";
    var key = config ? config.apiKey : "";
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
        if (response && response.data) {
            for (var i = 0; i < response.data.length; i++) {
                var agent = response.data[i];
                var name = agent.id;
                
                var modelData = { 
                    "name": name, 
                    "display_name": agent.name || name,
                    "provider": config ? config.instanceName : "openclaw" 
                };
                models.push(modelData);
            }
        }
        callback(models, null);
    }, null, headers);
}

function sendChat(text, sessionId, callback, config) {
    var url = (config && config.baseUrl) ? config.baseUrl + "/v1/chat/completions" : "http://localhost:18789/v1/chat/completions";
    
    var messages = [
        {
            role: "user",
            content: text
        }
    ];

    var data = {
        model: config ? config.model : "",
        messages: messages
    };
    
    if (sessionId) {
        data.session_id = sessionId;
    }

    var key = config ? config.apiKey : "";
    var headers = {};
    if (key) {
        headers["Authorization"] = "Bearer " + key;
    }

    return HttpClient.request("POST", url, function(response, error) {
        if (error) {
            callback(null, error, null);
            return;
        }

        if (response && response.choices && response.choices.length > 0) {
            var content = response.choices[0].message.content;
            var newSessionId = response.session_id || sessionId;
            var meta = { sessionId: newSessionId, stateful: true };
            if (response.usage) {
                meta.promptTokens = response.usage.prompt_tokens;
                meta.completionTokens = response.usage.completion_tokens;
                meta.totalTokens = response.usage.total_tokens;
            }
            callback(content, null, meta);
        } else {
            callback(null, "No response content", null);
        }
    }, data, headers);
}
