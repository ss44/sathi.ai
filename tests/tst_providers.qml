import QtTest

import "../providers/providers.js" as Providers

TestCase {
    name: "ProvidersSyntax"

    function test_providers_module_loads_and_exposes_api() {
        verify(typeof Providers.sendMessage === "function");
        verify(typeof Providers.sendMessageLegacy === "function");
        verify(typeof Providers.sendRaw === "function");
        verify(typeof Providers.setSmartContext === "function");
        verify(typeof Providers.setFastModel === "function");
        verify(typeof Providers.getProviderForInstance === "function");
    }
}