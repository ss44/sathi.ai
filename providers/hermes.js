.pragma library
.import "openai.js" as OpenAI

function baseUrl(url) {
    return (url || "http://localhost:8642").replace(/\/+$/, "").replace(/\/v1$/, "");
}

function listModels(callback, config) {
    OpenAI.listModels(callback, Object.assign({}, config, { baseUrl: baseUrl(config.baseUrl) }));
}

function sendChat(history, systemPrompt, callback, config) {
    var latest = null;
    for (var i = history.length - 1; i >= 0; i--) {
        if (history[i].role === "user") {
            latest = history[i];
            break;
        }
    }
    if (!latest || !config.sessionId) {
        callback(null, "Hermes requires a user message and an explicit session ID");
        return;
    }
    return OpenAI.sendChat([latest], "", callback, Object.assign({}, config, {
        baseUrl: baseUrl(config.baseUrl),
        headers: { "X-Hermes-Session-Id": config.sessionId },
        validateResponse: function(response, xhr) {
            var returnedId = xhr ? xhr.getResponseHeader("X-Hermes-Session-Id") : null;
            if (returnedId !== config.sessionId)
                return "Hermes did not confirm the requested session identity";
            var choice = response.choices && response.choices[0];
            if (choice && (choice.finish_reason === "error" || choice.finish_reason === "cancelled"))
                return (response.hermes && response.hermes.error) || "Hermes turn " + choice.finish_reason;
            return null;
        }
    }));
}
