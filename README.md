# 🎬 Media Optimizer (Interactive Media Cleaner)

A cross-platform, interactive command-line tool that cleans, optimizes, and strips bloated metadata from video files. Built for data hoarders and home theater enthusiasts, this script allows you to selectively keep specific audio and subtitle tracks while completely wiping unwanted attachments, global tags, and track statistics.

## ✨ Key Features
* **🧠 Smart Spatial Audio Logic:** Uses MediaInfo to scan for Dolby Atmos and DTS:X metadata. If spatial audio is detected, it preserves the track as an untouched `copy`. If standard lossless audio (TrueHD / DTS-HD MA) is detected, it converts it to `FLAC` to save massive amounts of storage space.
* **🧹 Deep Container Remux:** Instead of just editing tags, the tool performs a fresh remux using MKVToolNix. This ensures all "ghost" metadata is purged and track headers (like FLAC bitrate/info) are accurately updated.
* **🖱️ Drag-and-Drop Support:** No need to type out long file paths. Just drag your video file right into the terminal.
* **💻 Cross-Platform:** Native scripts available for Windows (PowerShell) and Linux/macOS (Bash).

---

## ⚙️ Prerequisites

This tool relies on a synergy of three powerful media tools. You must have them installed and added to your system's PATH.

### For Windows
Download and install the following tools. Make sure their `.exe` locations are added to your Windows Environment Variables (`PATH`).
1. **[FFmpeg](https://ffmpeg.org/download.html)**
2. **[MediaInfo (CLI Version)](https://mediaarea.net/en/MediaInfo/Download/Windows)** *(Must be the command-line version, not the GUI)*
3. **[MKVToolNix](https://mkvtoolnix.download/downloads.html#windows)** *(We use `mkvmerge.exe` included in the installation folder)*

### For Linux
Install the tools using your package manager. We also require `jq` to parse JSON outputs.
**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install ffmpeg mkvtoolnix mediainfo jq
```

### For macOS
Install the tools easily using [Homebrew](https://brew.sh/):
```bash
brew install ffmpeg mkvtoolnix media-info jq
```

---

## 🚀 How to Use

### On Windows
1. Open PowerShell.
2. Run the script:
   ```powershell
   .\InteractiveMediaCleaner.ps1
   ```
   *(Note: If Windows blocks the script, run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` to allow custom scripts).*
3. Drag and drop your video file into the window and hit Enter.
4. Follow the on-screen prompts to select your audio and subtitle tracks!

### On Linux & macOS
1. Open your Terminal.
2. Make the script executable (you only need to do this once):
   ```bash
   chmod +x InteractiveMediaCleaner.sh
   ```
3. Run the script:
   ```bash
   ./InteractiveMediaCleaner.sh
   ```
   *(Pro-Tip: You can also launch it and pass the file directly by running `./InteractiveMediaCleaner.sh "/path/to/movie.mkv"`)*
4. Follow the on-screen prompts to select your audio and subtitle tracks!

---

## 🛠️ How It Works (The Pipeline)
1. **Phase 1 (Scanning):** `ffprobe` scans the file and generates a clean, interactive list of all available audio and subtitle tracks while preserving original language metadata.
2. **Phase 2 (Logic):** `mediainfo` checks your chosen audio track for spatial object data to decide between passthrough copying or FLAC compression.
3. **Phase 3 (Scrubbing):** `ffmpeg` strips unwanted tracks, converts the audio, drops chapter metadata, and obliterates global metadata using `-map_metadata -1`.
4. **Phase 4 (Final Remux):** `mkvmerge` performs a fresh container remux. This step wipes remaining global/track tags, drops all attachments, updates the FLAC technical headers, and automatically sets your selected subtitle as the "Default Track."
```
