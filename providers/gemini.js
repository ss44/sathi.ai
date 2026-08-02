.pragma library
.import "httpClient.js" as HttpClient

var apiKey = "";
var currentModel = "";
var useGrounding = false;

function setApiKey(key) {
    apiKey = key;
}

function setModel(model) {
    currentModel = model;
}

function setUseGrounding(enabled) {
    useGrounding = enabled;
}

function listModels(callback) {
    var url = "https://generativelanguage.googleapis.com/v1beta/models";
    var headers = {};
    if (apiKey) {
        headers["x-goog-api-key"] = apiKey;
    }
    
    HttpClient.request("GET", url, function(response, error) {
        if (error) {
            callback(null, error);
            return;
        }

        var models = [];
        if (response.models) {
            for (var i = 0; i < response.models.length; i++) {
                var m = response.models[i];
                var name = m.name;
                if (name.startsWith("models/")) {
                    name = name.substring(7);
                }
                
                if (m.supportedGenerationMethods && m.supportedGenerationMethods.indexOf("generateContent") !== -1) {
                    var modelData = { "name": name };
                    if (m.displayName) {
                        modelData["display_name"] = m.displayName;
                    }
    
                    modelData["provider"] = "gemini";
                    models.push(modelData);
                }
            }
        }
        callback(models, null);
    }, null, headers);
}

function sendChat(history, systemPrompt, callback) {
    if (!apiKey) {
        callback(null, "API Key not set");
        return;
    }
    
    // Map standard history [{role: 'user'|'model', content: ''}] to Gemini format
    var contents = [];
    
    for(var i=0; i<history.length; i++) {
        var item = history[i];
        contents.push({
            role: item.role,
            parts: [{ text: item.content }]
        });
    }

    var url = "https://generativelanguage.googleapis.com/v1beta/models/" + currentModel + ":generateContent";
    
    var payload = {
        contents: contents
    };
    
    if (systemPrompt) {
         payload.system_instruction = {
            parts: { text: systemPrompt }
        };
    }
    
    console.info("[Gemini] Sending chat request. Grounding enabled: " + useGrounding);
    
    if (useGrounding) {
        payload.tools = [{ googleSearch: {} }];
    }

    var headers = {};
    if (apiKey) {
        headers["x-goog-api-key"] = apiKey;
    }

    HttpClient.request("POST", url, function(response, error) {
        if (error) {
            callback(null, error);
            return;
        }

        if (response.candidates && response.candidates.length > 0) {
            var candidate = response.candidates[0];
            var responseText = "";
            
            if (candidate.content && candidate.content.parts && candidate.content.parts.length > 0) {
                responseText = candidate.content.parts[0].text;
            }
            
            if (candidate.groundingMetadata) {
                console.info("[Gemini] Grounding metadata received: " + JSON.stringify(candidate.groundingMetadata));
            } else if (useGrounding) {
                console.info("[Gemini] Grounding was requested but no grounding metadata was returned by the API.");
            }
            
            var meta = response.usageMetadata ? { promptTokens: response.usageMetadata.promptTokenCount, completionTokens: response.usageMetadata.candidatesTokenCount, totalTokens: response.usageMetadata.totalTokenCount } : {};
            
            if (candidate.groundingMetadata) {
                meta.groundingMetadata = candidate.groundingMetadata;
            }
            
            callback(responseText, null, meta);
        } else {
            callback(null, "Empty response from API");
        }
    }, payload, headers);
}
