# Sathi.Ai

**Sathi** is a Generative AI client plugin designed for **Dank Material Linux**. It enables you to interact with Large Language Models (LLMs) directly from your desktop shell.

https://github.com/user-attachments/assets/0e90c1ff-e7d1-4b15-98a0-434727c99665

## Features

- 💬 **Desktop Chat Interface**: Talk to AI without opening a browser.
- ⚡ **Multi-Provider Support**: Supports **Google Gemini**, **OpenAI**, and local (or remote?) **Ollama** models.
- 🎨 **Markdown Support**: Chat bubbles support markdown formatting and clickable links.
- 🛠️ **Configurable**: Set your API keys and endpoints directly in settings.

## Installation

### Prerequisites

- Dank Material Shell
- A supported AI Provider ([Ollama](https://ollama.com)], [Gemini](https://aistudio.google.com/) or [OpenAI](https://platform.openai.com))

### 1. Install Plugin Dependencies
- Install the plugin to your plugins directory (`~/.config/DankMaterialShell/plugins`) by default.


### 2. Configuration

1. Enable the plugin in Dank Settings.
2. Open the **Sathi** settings page.
3. Configure your AI providers:
   - **Google Gemini**: Enter your API Key from [Google AI Studio](https://aistudio.google.com/).
   - **OpenAI**: Enter your API Key from [OpenAI Platform](https://platform.openai.com/api-keys).
   - **Ollama**: Enter your local server URL (default: `http://localhost:11434`).
4. (Optional) Set a custom **System Prompt** to define the AI's persona.

## 3. Usage

1. Click the **Sathi** widget in your shelf/panel.
2. Select your preferred model from the dropdown (Gemini models and local Ollama models will appear mixed).
3. Type your message and press Enter!

## Troubleshooting

- **"Script failed"** or **missing responses**:
  - Ensure your API Key is correct.
  - Check the `dms` logs (`DMS_LOG_LEVEL=debug dms run`) for more details.

## Motivation
- Dank Matter Shell is dope as hell. Actually made me like my desktop.
- Niri is amazing it made me want to use my laptop.
- I find Ai convenient but all the ai clients i tried just didn't fit with my new found niri flow.
- DMS plugin system was easy to work with and i wanted to learn and try something.

## Ai Disclosure
- While I take pride in writing a chunk of the code by hand and resolving logic that the AI just couldn't get right, I also used AI to do a bunch of tedious, monotonous tasks, which in my opinion is the perfect use of it.

## License

[MIT](LICENSE)
