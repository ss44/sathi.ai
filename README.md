# Sathi.Ai

**Sathi** is a Generative AI client plugin designed for **Dank Material Linux**. It enables you to interact with Large Language Models (LLMs) directly from your desktop shell.

> ⚠️ **Status: Early Beta**
>
> This project is currently in active development. Features may change, and bugs are to be expected.

## Features

- 💬 **Desktop Chat Interface**: Talk to AI without opening a browser.
- ⚡ **Multi-Provider Support**: Supports **Google Gemini** and local **Ollama** models.
- 🎨 **Markdown Support**: Chat bubbles support markdown formatting and clickable links.
- 🛠️ **Configurable**: Set your API keys and endpoints directly in settings.

## Installation

### Prerequisites

- Dank Material Shell
- (Optional) [Ollama](https://ollama.com/) running locally for local models.

### 1. Install Plugin Dependencies


### 2. Configuration

1. Enable the plugin in Dank Settings.
2. Open the **Sathi** settings page.
3. Configure your AI providers:
   - **Google Gemini**: Enter your API Key from [Google AI Studio](https://aistudio.google.com/).
   - **Ollama**: Enter your local server URL (default: `http://localhost:11434`).
4. (Optional) Set a custom **System Prompt** to define the AI's persona.

## Usage

1. Click the **Sathi** widget in your shelf/panel.
2. Select your preferred model from the dropdown (Gemini models and local Ollama models will appear mixed).
3. Type your message and press Enter!

## Troubleshooting

- **"Script failed"** or **missing responses**:
  - Ensure your API Key is correct.
  - Check the `dms` logs (`DMS_LOG_LEVEL=debug dms run`) for more details.

## License

[MIT](LICENSE)

## Acknowledgments
- Loading Gif https://giphy.com/gifs/pointer-cursor-mouse-XXH77SsudU3HW
