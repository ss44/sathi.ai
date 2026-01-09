# Sathi.Ai

**Sathi** is a Generative AI client plugin designed for **Dank Material Linux**. It enables you to interact with Large Language Models (LLMs) directly from your desktop shell.

> ⚠️ **Status: Early Beta**
>
> This project is currently in active development. Features may change, and bugs are to be expected.

## Features

- 💬 **Desktop Chat Interface**: Talk to AI without opening a browser.
- ⚡ **Powered by Gemini**: Allows you to select any supported model.
- 🎨 **Markdown Support**: Chat bubbles support markdown formatting and clickable links.
- 🛠️ **Configurable**: Set your API key directly in the plugin settings.

## Installation

### Prerequisites

- Dank Material Shell
- Python 3.x
- `pip`

### 1. Install Plugin Dependencies

The plugin uses a local Python virtual environment to manage its dependencies securely.

```bash
# Navigate to the plugin folder
cd /path/to/dank-ai-plugin

# Create virtual environment and install requirements
python3 -m venv backend/.venv
backend/.venv/bin/pip install -r backend/requirements.txt
```

### 2. Configuration

1. Enable the plugin in Dank Settings.
2. Open the **Sathi** settings page.
3. Enter your **Google Gemini API Key**.
   - You can get a key from [Google AI Studio](https://aistudio.google.com/).

## Usage

1. Click the **Sathi** widget in your shelf/panel.
2. If configured correctly, a chat interface will pop up.
3. Type your message and press Enter!

## Troubleshooting

- **"Script failed"** or **missing responses**:
  - Ensure your API Key is correct.
  - Check that the virtual environment is set up correctly in `backend/.venv`.
  - Check the `dms` logs (`DMS_LOG_LEVEL=debug dms run`) for more details.

## License

[MIT](LICENSE)

## Acknowledgments
- Loading Gif https://giphy.com/gifs/pointer-cursor-mouse-XXH77SsudU3HW
