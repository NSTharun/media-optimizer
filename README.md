# 🎬 Media Optimizer (Interactive Media Cleaner)

A cross-platform, interactive command-line tool that cleans, optimizes, and strips bloated metadata from video files. Built for data hoarders and home theater enthusiasts, this script allows you to selectively keep specific audio and subtitle tracks while completely wiping unwanted attachments, global tags, and track statistics.

## ✨ Key Features
* **🧠 Smart Spatial Audio Logic:** Uses MediaInfo to scan for Dolby Atmos and DTS:X metadata. If spatial audio is detected, it preserves the track as an untouched `copy`. If standard lossless audio (TrueHD / DTS-HD MA) is detected, it converts it to `FLAC` to save massive amounts of storage space.
* **🧹 Total Metadata Wipe:** Drops all embedded cover art, attachments, and global/track tags using MKVToolNix, resulting in a perfectly clean `.mkv` file.
* **🖱️ Drag-and-Drop Support:** No need to type out long file paths. Just drag your video file right into the terminal.
* **💻 Cross-Platform:** Native scripts available for Windows (PowerShell) and Linux/macOS (Bash).

---

## ⚙️ Prerequisites

This tool relies on a synergy of three powerful media tools. You must have them installed and added to your system's PATH.

### For Windows
Download and install the following tools. Make sure their `.exe` locations are added to your Windows Environment Variables (`PATH`).
1. **[FFmpeg](https://ffmpeg.org/download.html)**
2. **[MediaInfo (CLI Version)](https://mediaarea.net/en/MediaInfo/Download/Windows)** *(Must be the command-line version, not the GUI)*
3. **[MKVToolNix](https://mkvtoolnix.download/downloads.html#windows)** *(We use `mkvpropedit.exe` included in the installation folder)*

### For Linux
Install the tools using your package manager. We also require `jq` to parse JSON outputs.
**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install ffmpeg mkvtoolnix mediainfo jq
