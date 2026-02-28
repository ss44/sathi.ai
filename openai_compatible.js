.pragma library

/**
 * Shared stateless implementation of the OpenAI-compatible API.
 * Providers that use the OpenAI API format delegate to these functions,
 * passing their own state (baseUrl, apiKey, etc.) as parameters.
 */

function request(method, url, apiKey, extraHeaders, callback, data) {
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
    if (extraHeaders) {
        for (var key in extraHeaders) {
            xhr.setRequestHeader(key, extraHeaders[key]);
        }
    }
    if (data) {
        xhr.send(JSON.stringify(data));
    } else {
        xhr.send();
    }
}

function listModels(baseUrl, apiKey, provider, extraHeaders, callback) {
    var url = baseUrl + "/models";
    request("GET", url, apiKey, extraHeaders, function(response, error) {
        if (error) {
            callback(null, error);
            return;
        }

        var models = [];
        if (response.data) {
            for (var i = 0; i < response.data.length; i++) {
                var m = response.data[i];
                var modelData = {
                    "name": provider + ":" + m.id,
                    "display_name": m.id,
                    "provider": provider
                };
                models.push(modelData);
            }
        }
        callback(models, null);
    });
}

function sendChat(baseUrl, apiKey, model, extraHeaders, history, systemPrompt, callback) {
    var url = baseUrl + "/chat/completions";

    var messages = [];
    if (systemPrompt) {
        messages.push({
            role: "system",
            content: systemPrompt
        });
    }

    for (var i = 0; i < history.length; i++) {
        var item = history[i];
        var r = (item.role === 'model') ? 'assistant' : item.role;
        messages.push({
            role: r,
            content: item.content
        });
    }

    var data = {
        model: model,
        messages: messages
    };

    request("POST", url, apiKey, extraHeaders, function(response, error) {
        if (error) {
            callback(null, error);
            return;
        }

        if (response.choices && response.choices.length > 0) {
            var content = response.choices[0].message.content;
            callback(content, null);
        } else {
            callback(null, "No response content");
        }
    }, data);
}
