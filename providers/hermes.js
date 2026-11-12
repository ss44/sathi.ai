.pragma library
.import "httpClient.js" as HttpClient

function listModels(callback, config) {
    var url = (config && config.baseUrl) ? config.baseUrl + "/api/agents" : "http://localhost:8080/api/agents";
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
        if (response && response.agents) {
            for (var i = 0; i < response.agents.length; i++) {
                var agent = response.agents[i];
                var name = agent.id;
                
                var modelData = { 
                    "name": name, 
                    "display_name": agent.name || name,
                    "provider": config ? config.instanceName : "hermes" 
                };
                models.push(modelData);
            }
        } else if (response && Array.isArray(response)) {
             for (var j = 0; j < response.length; j++) {
                var a = response[j];
                var n = a.id || a.name || "default";
                models.push({
                    "name": n,
                    "display_name": a.name || n,
                    "provider": config ? config.instanceName : "hermes" 
                });
             }
        }
        callback(models, null);
    }, null, headers);
}

function sendChat(text, sessionId, callback, config) {
    var url = (config && config.baseUrl) ? config.baseUrl + "/api/chat" : "http://localhost:8080/api/chat";
    
    var data = {
        agent_id: config ? config.model : "",
        message: text
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

        if (response) {
            var content = response.message || response.response || (response.data && response.data.message) || "";
            var newSessionId = response.session_id || (response.data && response.data.session_id) || sessionId;
            var meta = { sessionId: newSessionId, stateful: true };
            callback(content, null, meta);
        } else {
            callback(null, "No response content", null);
        }
    }, data, headers);
}
