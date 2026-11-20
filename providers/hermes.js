.pragma library
.import "openai.js" as OpenAI
.import "httpClient.js" as HttpClient

var discoveryRefreshes = {};

function baseUrl(url) {
    return (url || "http://localhost:8642").replace(/\/+$/, "").replace(/\/v1$/, "");
}

function listModels(callback, config) {
    var url = baseUrl(config.baseUrl);
    OpenAI.listModels(function(aliases, aliasError) {
        var headers = config.apiKey ? { "Authorization": "Bearer " + config.apiKey } : {};
        // Full refresh probes every saved custom endpoint; throttle automatic reloads.
        var now = Date.now();
        var refresh = !discoveryRefreshes[url] || now - discoveryRefreshes[url] >= 300000;
        if (refresh) discoveryRefreshes[url] = now;
        HttpClient.request("GET", url + "/api/model/options?include_unconfigured=false" + (refresh ? "&refresh=true" : ""), function(response, error) {
            var models = !error ? inventoryModels(response) : [];
            var advertised = aliases || [];
            models.forEach(function(m) {
                if (aliasError)
                    m.routingError = "Cannot verify Hermes route aliases; reload models before selecting an upstream model.";
                else if (advertised.some(function(alias) { return alias.name === m.name; }))
                    m.routingError = "Hermes route alias shadows upstream model '" + m.name
                        + "'; select the alias or rename it on the server. Explicit provider cannot bypass aliases.";
            });
            // Namespace upstream routes separately, including aliases that resemble our IDs.
            advertised.forEach(function(m) { m.modelId = JSON.stringify(["alias", m.name]); });
            if (advertised.length || models.length)
                callback(advertised.concat(models), null);
            else
                callback(error || aliasError ? null : [], error || aliasError);
        }, null, headers);
    }, Object.assign({}, config, { baseUrl: url }));
}

function inventoryModels(response) {
    var models = [];
    var seen = {};
    if (!response || !Array.isArray(response.providers)) return models;
    response.providers.forEach(function(row) {
        if (!row || typeof row.slug !== "string" || !row.slug.trim()
                || row.authenticated === false || !Array.isArray(row.models)) return;
        row.models.forEach(function(name) {
            if (typeof name !== "string" || !name.trim()
                    || (Array.isArray(row.unavailable_models) && row.unavailable_models.indexOf(name) !== -1)) return;
            var id = JSON.stringify(["upstream", row.slug, name]);
            if (seen[id]) return;
            seen[id] = true;
            models.push({ name: name, modelId: id, upstreamProvider: row.slug,
                display_name: name + " (" + (row.name || row.slug) + " / " + row.slug + ")" });
        });
    });
    return models;
}

function sendChat(history, systemPrompt, callback, config) {
    if (config.routingError) {
        callback(null, config.routingError);
        return;
    }
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
