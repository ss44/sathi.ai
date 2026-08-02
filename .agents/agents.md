# Sathi AI - Project Context & Developer Knowledge Base

This file contains accumulated knowledge, architectural decisions, and tips for developing the Sathi AI plugin for Dank Material Shell (DMS). Future agents and contributors should read this file to understand the project structure and avoid repeating past mistakes.

## Project Overview
Sathi AI is a desktop Generative AI chat widget built for Dank Material Shell. It interfaces with various LLMs without needing a browser.
- **Tech Stack:** QML (QtQuick) for the UI, JavaScript for logic.
- **Environment:** Runs within Quickshell. There is no Node.js, no NPM, and no DOM. Standard web APIs like `fetch` are not available; we use standard QML `XMLHttpRequest` for network calls.

## Project Structure
- `Sathi.qml`: The main entry point and UI container for the chat popout.
- `Settings.qml`: The main settings page entry point.
- `ui/`: Contains the visual components.
  - `ChatBubble.qml`: Renders individual chat messages. Handles Markdown parsing, code blocks, Google Search grounding chips, and token/cost metadata hovering.
  - `ChatBottomBar.qml`: The input area, AI model selector, clear chat, and settings shortcuts.
  - `AiSelector.qml`: The dropdown component for selecting active models, grouping them by provider name.
  - `ProviderList.qml`: The core Settings UI for dynamically adding/removing/editing provider instances.
  - `ChatBackendSettings.qml` & `ChatBackendChat.qml`: Invisible logic components bridging the UI to the `providers.js` logic.
- `providers/`: The engine room for LLM communication.
  - `providers.js`: The central orchestrator/registry. Manages instances, loaded models, history passing, and cost calculations. Uses `.pragma library` to act as a singleton.
  - `openai.js`, `gemini.js`, `anthropic.js`: API-specific implementations. Note: `openai.js` handles OpenAI, Ollama, LM Studio, and all generic OpenAI-compatible endpoints.
  - `crypto.js`: Provides light obfuscation (`enc:v1:...`) for API keys before saving them to DMS settings.
- `chatHistory.js`: Manages saving/loading/pruning the chat history via the DMS plugin service.

## Core Architectural Decisions

### 1. Multi-Provider Instances & "OpenAI Compatible"
Instead of hardcoding one key per service, the plugin supports *Provider Instances*. A user can have multiple "OpenAI Compatible" instances (e.g., one for actual OpenAI, one for a local Ollama server at `http://localhost:11434`, and one for LM Studio).
- Instances are tracked via a unique `id` generated at creation (e.g., `prov_1722403664_123`).
- This decouples the internal routing from the user-editable display `name`. If a user renames "My Local Ollama", the plugin doesn't lose track of it.

### 2. Model ID Collision Prevention
Different providers might host models with the exact same name (e.g., a local Ollama and a remote vLLM server both offering `llama3`). 
- To prevent routing collisions, models are tracked internally using a compound ID: `instanceId|modelName` (e.g., `prov_123|llama3`).
- When sending a request, the `providers.js` splits this back up, routing the request to the correct URL/Key and sending only the `modelName` to the API.

### 3. Encrypted Credentials
DMS plugins save settings to plain text JSON files. To prevent casual shoulder-surfing or accidental sharing of API keys:
- Keys are run through a simple XOR + Base64 obfuscation in `crypto.js`.
- They are saved with an `enc:v1:` prefix. If the prefix is missing, the system assumes it's a legacy plain-text key and attempts to migrate it.

### 4. Google Search Grounding (Gemini)
Gemini supports internet grounding. If enabled on a Gemini provider instance:
- `googleSearch: {}` is injected into the API payload tools.
- The response returns `groundingMetadata`.
- `ChatBubble.qml` intercepts this metadata, filters out duplicate URLs, and displays clickable chips below the AI's response pointing to the source articles.

### 5. XHR Limitations & HTTP Client
Since there is no `fetch` in QML, `XMLHttpRequest` is the primary network tool. Do not rewrite XHR boilerplate for every new provider; always use the shared `httpClient.js` library imported into provider implementations.

### 6. Wayland/Quickshell Focus
The `WlrKeyboardFocus.OnDemand` hack inside `Sathi.qml` manages Wayland window focus and interactivity. It dynamically sets the `customKeyboardFocus` property on the inner Quickshell popout so that users can interact with the chat widget while keeping popout stickiness behavior intact.

### 7. Pricing Updates
The `modelPricing` object is hardcoded in `providers.js`. If OpenAI, Anthropic, or Gemini change their pricing, this object must be manually updated to keep the UI cost estimates accurate.

### 8. State Wrappers
`ChatBackendChat.qml` and `ChatBackendSettings.qml` act as invisible bridge components. They wire the QML UI signals directly to the JavaScript logic (`providers.js` and `chatHistory.js`). When wiring up new functionality, add your properties and signals to these wrappers instead of dumping logic directly into visual QML components.

## Development Tips & Gotchas

1. **Logging Visibility:**
   - Always use `console.info`, `console.warn`, or `console.error` for debugging. Standard `console.log` is often swallowed or hidden depending on the `DMS_DEBUG_LEVEL` or Quickshell filtering. Prefix logs with the module name (e.g., `[Providers] Fetching...`) to trace execution flows.

2. **QML Property Binding Loops (Settings Reloading):**
   - Be extremely careful when binding UI components to global `pluginData` settings.
   - Example: In the past, writing to `chatHistory` triggered a global settings update, which cascaded into reloading the API keys, which wiped the loaded models list mid-chat. 
   - *Fix:* Use debouncing (via `Timer`) and hash-checking (comparing old vs. new values) before doing heavy resets like clearing `loadedModels`.

3. **QML Scoping Issues:**
   - Rely on explicit `id` references (e.g., `richColumn.uniqueGroundingChunks`) rather than relative `parent.` references. QML layout nesting often breaks `parent` scope expectations, resulting in silently failed property evaluations.

4. **Duck Typing Settings Injection:**
   - To access the DMS `pluginService.savePluginData` safely without complex imports across arbitrary depths, we use a tree-walking function `findSettings(item)` inside components like `ProviderList.qml` to crawl up the parent tree until it finds the root `Settings` object that exposes `loadValue`/`saveValue`.

5. **Clipboard Quirks:**
   - Copying rich text/markdown to the clipboard natively in QML can be tricky. Sathi uses a hidden `TextEdit` component (`copyHelper`), updates its text, calls `selectAll()`, and then `copy()`. This avoids needing to execute shell commands to interface with Wayland/X11 clipboards.

## Getting Started on a New Task
- Check if your task modifies how models are fetched. If so, update `openai.js` (for standard APIs) and test with local Ollama to ensure the `baseUrl` override isn't broken.
- Any UI changes to `Settings.qml` should be tested to ensure the `customProviders` JSON array serializes correctly.
