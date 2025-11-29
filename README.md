# mpv-shazam

A mpv script that identifies songs playing in the current media file using [ShazamIO](https://github.com/shazamio/shazamio). It can recognize songs on demand or continuously listen for changes.

## Features

- **On-demand Recognition:** Press a key to identify the current song.
- **Continuous Mode:** Automatically recognize songs periodically (useful for radio streams or long mixes).
- **OSD Overlay:** Displays Album Art, Title, Artist, Album, Year, Genre, and Label on screen.
- **Metadata Update:** Updates the window title and internal metadata with the recognized song info.
- **Cross-platform:** Works on Windows, Linux, and macOS (provided dependencies are met).

## Requirements

- **mpv** (0.33.0 or later recommended)
- **FFmpeg** (must be in your system PATH)
- **Python** 3.8 or later

## Installation

1.  **Locate your mpv scripts directory:**
    -   **Windows:** `%APPDATA%\mpv\scripts` or portable install `portable_config\scripts`
    -   **Linux/macOS:** `~/.config/mpv/scripts`

2.  **Copy the script:**
    Clone or download this repository into a folder named `shazam` inside your scripts directory.
    ```
    .../scripts/
    └── shazam/
        ├── main.lua
        ├── recognizer.py
        └── requirements.txt
    ```

3.  **Set up the Python environment:**
    The script requires a dedicated Python virtual environment to avoid conflicts.

    **Windows:**
    Open a terminal in the `shazam` folder and run:
    ```powershell
    python -m venv .venv
    .\.venv\Scripts\pip install -r requirements.txt
    ```

    **Linux/macOS:**
    Open a terminal in the `shazam` folder and run:
    ```bash
    python3 -m venv .venv
    ./.venv/bin/pip install -r requirements.txt
    ```

    *Note: If you prefer to use a system-wide python or a different venv location, see [Configuration](#configuration).*

## Configuration

You can configure the script using a `script-opts` file (usually `script-opts/shazam.conf` in your mpv config directory) or via command line.

**Available Options:**

-   `python_path`: Manually specify the path to the python executable. Useful if the auto-detection of the `.venv` fails or if you want to use a global python installation.

**Example `script-opts/shazam.conf`:**

```ini
python_path=C:\Python39\python.exe
```

## Usage

| Key | Action |
| :--- | :--- |
| **y** | Recognize the song currently playing. |
| **Shift+y** | Toggle continuous recognition mode. |

-   **One-time recognition (`y`):** Takes a 3-second sample and attempts to identify the song.
-   **Continuous recognition (`Shift+y`):** Repeatedly identifies songs. Great for live streams. If video is disabled (audio only), it may display album art as a video track.

## Troubleshooting

-   **"Python script failed or crashed":** Ensure the `.venv` is created correctly and `shazamio` is installed. Check the console output for detailed Python errors.
-   **FFmpeg error:** Ensure `ffmpeg` is installed and accessible from your system's PATH.

## License

MIT
