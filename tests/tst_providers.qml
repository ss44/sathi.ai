import QtTest

import "../providers/providers.js" as Providers
import "../providers/hermes.js" as Hermes
import "../providers/httpClient.js" as HttpClient

TestCase {
    name: "ProvidersSyntax"
    property var originalRequest

    function init() { originalRequest = HttpClient.request; Hermes.discoveryRefreshes = {}; }
    function cleanup() { HttpClient.request = originalRequest; }

    function test_hermes_inventory() {
        var models = Hermes.inventoryModels({ providers: [
            { slug: "one", name: "First", models: ["shared", "locked", "shared", null], unavailable_models: ["locked"] },
            { slug: "two", models: ["shared"] },
            { slug: "unauth", authenticated: false, models: ["hidden"] },
            { slug: "", models: ["bad"] }, null
        ] });
        compare(models.length, 2);
        compare(models[0].name, "shared");
        compare(models[0].upstreamProvider, "one");
        verify(models[0].display_name.indexOf("First") !== -1);
        verify(models[0].modelId !== models[1].modelId);
        compare(Hermes.inventoryModels({ providers: {} }).length, 0);
    }

    function test_hermes_registry_routes_and_filters() {
        Providers.clearProviders();
        Providers.addCustomProvider("hermes", "Hermes", "", "http://localhost:8642", false, "hermes-test", "shared");
        HttpClient.request = function(method, url, callback) {
            if (url.indexOf("/v1/models") !== -1)
                callback({ data: [{ id: JSON.stringify(["upstream", "one", "shared"]) }] }, null);
            else
                callback({ providers: [{ slug: "one", models: ["shared", "other"] },
                                        { slug: "two", models: ["shared"] }] }, null);
        };
        var result;
        Providers.fetchModelsForInstance("hermes-test", function(models, error) { verify(!error); result = models; });
        compare(result.length, 3);
        verify(result[0].id !== result[1].id);
        verify(result[1].id !== result[2].id);
        var sessions = [];
        var fakeProvider = { sendChat: function(history, prompt, callback, config) {
            sessions.push(config.sessionId);
            compare(config.model, "shared");
            verify(config.upstreamProvider === "one" || config.upstreamProvider === "two");
        } };
        var instance = { id: "hermes-test", type: "hermes", url: "http://localhost:8642" };
        Providers.sendStatefulMessage("test", result[1], instance, fakeProvider, function() {});
        Providers.sendStatefulMessage("test", result[2], instance, fakeProvider, function() {});
        Providers.sendStatefulMessage("test", result[1], instance, fakeProvider, function() {});
        verify(sessions[0] !== sessions[1]);
        compare(sessions[0], sessions[2]);
        Providers.clearProviders();
    }

    function test_hermes_discovery_data() {
        return [ { tag: "inventory", failed: false }, { tag: "alias fallback", failed: true } ];
    }

    function test_hermes_discovery(data) {
        var calls = [];
        HttpClient.request = function(method, url, callback, body, headers) {
            calls.push(url);
            compare(headers.Authorization, "Bearer test");
            if (url.indexOf("/v1/models") !== -1)
                callback({ data: [{ id: "hermes-agent" }, { id: "profile-alias" }] }, null);
            else {
                compare(url, "http://localhost:8642/p/work/api/model/options?include_unconfigured=false&refresh=true");
                callback(data.failed ? null : { providers: [{ slug: "custom:work", models: ["org/model"] }] },
                         data.failed ? "HTTP Error: 404" : null);
            }
        };
        var result;
        Hermes.listModels(function(models, error) { verify(!error); result = models; },
                          { baseUrl: "http://localhost:8642/p/work/v1/", apiKey: "test" });
        compare(calls.length, 2);
        compare(result.length, data.failed ? 2 : 3);
        compare(result[1].name, "profile-alias");
        if (!data.failed) compare(result[2].upstreamProvider, "custom:work");
    }

    function test_hermes_chat_data() {
        return [{ tag: "upstream", provider: "custom:work" }, { tag: "alias", provider: undefined }];
    }

    function test_hermes_full_discovery_throttle_and_collision_data() {
        return [{ tag: "collision", aliasFailure: false }, { tag: "unknown aliases", aliasFailure: true }];
    }

    function test_hermes_full_discovery_throttle_and_collision(data) {
        var inventories = [];
        var sent = false;
        HttpClient.request = function(method, url, callback) {
            if (method === "POST") { sent = true; return; }
            if (url.indexOf("/v1/models") !== -1)
                callback(data.aliasFailure ? null : { data: [{ id: "shared" }] }, data.aliasFailure ? "HTTP Error: 503" : null);
            else {
                inventories.push(url);
                callback({ providers: [{ slug: "openai-luna", models: ["shared"] },
                                         { slug: "openai-sol", models: ["shared"] }] }, null);
            }
        };
        var result;
        function discovered(models, error) { verify(!error); result = models; }
        var config = { baseUrl: "http://localhost:8642" };
        Hermes.listModels(discovered, config);
        Hermes.listModels(discovered, config);
        verify(inventories[0].indexOf("refresh=true") !== -1);
        verify(inventories[1].indexOf("refresh=true") === -1);
        Hermes.discoveryRefreshes[config.baseUrl] -= 300001;
        Hermes.listModels(discovered, config);
        verify(inventories[2].indexOf("refresh=true") !== -1);
        compare(result.length, data.aliasFailure ? 2 : 3);
        var first = result[data.aliasFailure ? 0 : 1];
        verify(first.modelId !== result[result.length - 1].modelId);
        var expected = data.aliasFailure ? "Cannot verify" : "shadows";
        verify(first.routingError.indexOf(expected) !== -1);
        Hermes.sendChat([{ role: "user", content: "test" }], "", function(text, error) {
            verify(!text); verify(error.indexOf(expected) !== -1);
        }, Object.assign({}, first, { sessionId: "test" }));
        verify(!sent);
    }

    function test_hermes_registry_to_wire() {
        Providers.clearProviders();
        Providers.addCustomProvider("hermes", "Hermes", "", "http://localhost:8642", false, "wire-test", "");
        var sessions = [];
        var providers = [];
        HttpClient.request = function(method, url, callback, body, headers) {
            if (method === "GET") {
                callback(url.indexOf("/v1/models") !== -1 ? { data: [] } : {
                    providers: [{ slug: "openai-luna", models: ["shared"] },
                                { slug: "openai-sol", models: ["shared"] }] }, null);
                return;
            }
            compare(body.model, "shared");
            providers.push(body.provider);
            sessions.push(headers["X-Hermes-Session-Id"]);
            callback({ choices: [{ message: { content: "answer" } }] }, null,
                     { getResponseHeader: function() { return headers["X-Hermes-Session-Id"]; } });
        };
        var models;
        Providers.fetchModelsForInstance("wire-test", function(result) { models = result; });
        // The adapter reads the existing history, not the text argument.
        var originalSend = Hermes.sendChat;
        var adapter = { sendChat: function(history, prompt, callback, config) {
            return originalSend([{ role: "user", content: "test" }], prompt, callback, config);
        } };
        var instance = { id: "wire-test", type: "hermes", url: "http://localhost:8642" };
        [models[0], models[1], models[0]].forEach(function(model) {
            Providers.sendStatefulMessage("test", model, instance, adapter, function(text, error) { verify(!error); });
        });
        compare(providers.join(","), "openai-luna,openai-sol,openai-luna");
        verify(sessions[0] !== sessions[1]);
        compare(sessions[0], sessions[2]);
        Providers.clearProviders();
    }

    function test_hermes_chat(data) {
        HttpClient.request = function(method, url, callback, body, headers) {
            compare(method, "POST");
            compare(url, "http://localhost:8642/p/work/v1/chat/completions");
            compare(body.model, "org/model");
            compare(body.provider, data.provider);
            compare(body.messages.length, 1);
            compare(body.messages[0].content, "latest");
            compare(headers["X-Hermes-Session-Id"], "session-test");
            callback({ choices: [{ message: { content: "answer" } }] }, null,
                     { getResponseHeader: function() { return "session-test"; } });
            return "request";
        };
        compare(Hermes.sendChat([{ role: "user", content: "old" }, { role: "user", content: "latest" }],
                               "ignored", function(text, error) { compare(text, "answer"); verify(!error); },
                               { baseUrl: "http://localhost:8642/p/work", model: "org/model",
                                   upstreamProvider: data.provider, sessionId: "session-test" }), "request");
    }

    function test_providers_module_loads_and_exposes_api() {
        verify(typeof Providers.sendMessage === "function");
        verify(typeof Providers.sendMessageLegacy === "function");
        verify(typeof Providers.sendRaw === "function");
        verify(typeof Providers.setSmartContext === "function");
        verify(typeof Providers.setFastModel === "function");
        verify(typeof Providers.getProviderForInstance === "function");
    }
}
