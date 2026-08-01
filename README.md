# SathiAi

**Sathi** is a Generative AI client plugin designed particularly for **Dank Material Shell**. It enables you to interact with Large Language Models (LLMs) directly from your desktop shell making it easy to ask questions and find commands without needing to switch apps or open a browser.

https://github.com/user-attachments/assets/0e90c1ff-e7d1-4b15-98a0-434727c99665

## Features

- 💬 **Desktop Chat Interface**: Talk to AI without opening a browser.
- ⚡ **Multi-Instance Support**: Add multiple provider instances (e.g., work vs. personal keys, remote vs. local models).
- 🔌 **Unified Endpoints**: Connect to **Google Gemini**, **Anthropic Claude**, and any **OpenAI Compatible** endpoint (supports OpenAI, Ollama, LM Studio, vLLM, etc.).
- 🌐 **Google Search Grounding**: Enable real-time internet grounding for Gemini models, complete with clickable source chips!
- 🎨 **Rich Formatting**: Chat bubbles support markdown formatting, syntax-highlighted code blocks, and easy "copy to clipboard" functionality.
- 📊 **Token & Cost Tracking**: Hover over the info icon on messages to view token usage and estimated costs.
- 💾 **Persistent History**: Optionally persist your chat sessions across reboots.
- 🎭 **Context Control**: Customize the System Prompt to define the AI's persona.
- 📌 **Pin to Top**: Keep the chat visible while you work. You can still use other apps underneath it.

## Limitations

- When listing models, we get all available models offered by a service. Users will need to know which model they want to use, especially on local servers.
- Complex nested markdown (e.g., tables) may have rendering quirks in QML `TextEdit`.

## Installation

### Prerequisites

- Dank Material Shell
- A supported AI Provider API key or an OpenAI Compatible local server like [Ollama](https://ollama.com) or [LM Studio](https://lmstudio.ai/).

### 1. Install Plugin Dependencies

- Install the plugin to your plugins directory (`~/.config/DankMaterialShell/plugins`) by default.
- Enable the plugin in the Dank Material Shell plugins screen.
- Add the widget to your widgets tab.
- (Optional) - Add a shortcut key to open the plugin. In `niri/config.kdl` you can add something like: `Mod+Shift+Space { spawn-sh "dms ipc call widget toggle sathiAi"; }`

### 2. Configuration

1. Enable the plugin in Dank Settings.
2. Open the **Sathi** settings page.
3. Under the **AI Providers** section, select a Provider Type:
   - **Google Gemini**: Requires an API Key from [Google AI Studio](https://aistudio.google.com/). Allows enabling Google Search Grounding.
   - **Anthropic Claude**: Requires an API Key from the [Claude Platform](https://platform.claude.com/settings/keys).
   - **OpenAI Compatible**: Can be used for OpenAI itself, or local servers like Ollama/LM Studio.
     - For OpenAI: Leave the URL as `https://api.openai.com` and enter your API Key.
     - For Ollama: Set the URL to `http://localhost:11434` and leave the API key blank.
     - For LM Studio: Set the URL to `http://localhost:1234` and leave the API key blank.
4. Click **Add Provider**. You can add as many as you need!
5. (Optional) Set a custom **System Prompt** to define the AI's persona, and configure your History limits.

## Usage

1. Click the **Sathi** widget in your shelf/panel or trigger your custom shortcut.
2. The bottom bar contains a quick-access settings icon, a clear-chat button, and a pin toggle.
3. Select your preferred model from the dropdown. It groups models by your configured provider names.
4. Type your message and press Enter!

## Troubleshooting

- **"No models available" / "Empty response"**:
  - Ensure your API Keys are correct and have remaining quota.
  - If using Ollama/local servers, ensure the service is running and accessible at the provided URL.
  - Check the `dms` logs (`DMS_LOG_LEVEL=debug dms run`) for more details. The plugin logs extensive diagnostic information prefixed with `[Providers]`.

## Motivation

- Dank Matter Shell is dope as hell. Actually made me like my desktop.
- Niri is amazing it made me want to use my laptop.
- I find Ai convenient but all the ai clients i tried just didn't fit with my new found niri flow.
- DMS plugin system was easy to work with and i wanted to learn and try something.

## Ai Disclosure

Don't be surprised to learn that the AI agent was heavily vibe coded. (I hate the term vibe coded, so lets just say AI assisted.)

While I take pride in having written a big chunk of the initial code that  got the project started by hand and resolving logic that the AI just couldn't get right, I also used AI to do a bunch of tedious, monotonous tasks, which in my opinion is the perfect use of it.

Initially I wanted to learn QML which was the motivation behind getting this started. But as it became more useful to me the more I leaned on AI to fill in gaps. As the app grew so did my reliance on AI to keep it going. 

Call it slop - but I still think I did a pretty good job dictating its direction.

## Screenshots

- <img width="1386" height="938" alt="sathi-ai" src="https://github.com/user-attachments/assets/9721effc-c5e0-4269-8170-a4e0b8a95d02" />

## Attributions

<a href="https://www.flaticon.com/free-icons/sparkle" title="sparkle icons">Sparkle icons created by Muhammad_Usman - Flaticon</a>

## License

[MIT](LICENSE)
