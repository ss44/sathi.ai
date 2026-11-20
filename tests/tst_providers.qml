import QtTest

import "../providers/providers.js" as Providers
import "../providers/hermes.js" as Hermes
import "../providers/httpClient.js" as HttpClient

TestCase {
    name: "ProvidersSyntax"
    property var originalRequest

    function init() { originalRequest = HttpClient.request; }
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
                compare(url, "http://localhost:8642/p/work/api/model/options?include_unconfigured=false");
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
