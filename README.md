# Interactive Media Cleaner (FFmpeg + MKVToolNix)

A custom Windows PowerShell CLI tool designed to aggressively optimize MKV video files. It saves storage space and ensures maximum device compatibility by keeping only the tracks you want, smartly converting lossless audio, and deep-cleaning all junk metadata.

This script uses **FFmpeg** as the heavy-duty engine for stream extraction and audio conversion, and **MKVToolNix** as the final polisher to wipe stubborn container tags.

## 🛠️ The Workflow & Features

### 1. Video Processing
* Keeps the primary video stream untouched.
* Forces the video track language to `undefined` (`und`).
* Automatically removes the video track title.

### 2. Smart Audio Logic
* Scans and displays all audio tracks for you to choose from.
* Keeps **only** the selected audio track and drops the rest.
* **Smart Conversion:** If you select a **DTS-HD MA** or **Dolby TrueHD** track, the script uses MediaInfo to check for spatial audio (Atmos or DTS:X). 
  * If it lacks spatial metadata, it converts the track to **FLAC** to save file size while remaining 100% lossless.
  * If it has Atmos/DTS:X (or is a lossy format like AC3/E-AC3), it leaves it untouched.
* Removes the title of the selected audio track.

### 3. Subtitle Processing
* Scans and displays all subtitle tracks.
* Allows you to select exactly one subtitle track to keep, or enter `0` to strip all subtitles from the file entirely.
* Removes the title of the selected subtitle track.
* Drops all unselected subtitle tracks.

### 4. Deep Clean & Metadata Sanitization
* **FFmpeg Phase:** Completely removes the embedded file title, all chapter markers, and all image attachments (like cover art).
* **Interactive Naming:** Pauses the workflow after processing to let you type the exact name for your new file.
* **MKVToolNix Phase:** Passes the newly created file to `mkvpropedit` to surgically wipe all global MKV tags and track-specific tags for a pristine MediaInfo profile.

## ⚙️ Prerequisites

For this script to function, you must be on Windows and have the following three command-line tools installed and added to your system's **PATH** environment variable:

1. **[FFmpeg](https://ffmpeg.org/download.html)** (Specifically `ffmpeg` and `ffprobe`)
2. **[MediaInfo CLI](https://mediaarea.net/en/MediaInfo/Download/Windows)** (You must download the **CLI** version, not the GUI)
3. **[MKVToolNix](https://mkvtoolnix.download/downloads.html#windows)** (Specifically `mkvpropedit`)

## 🚀 How to Use

1. Download the `InteractiveMediaCleaner.ps1` script.
2. Right-click the script and select **Run with PowerShell** (or run it directly from your terminal).
3. Paste the file path of the video you want to process when prompted.
4. Follow the on-screen menu to select your audio and subtitle IDs.
5. Wait for FFmpeg to finish processing.
6. Type the final name for your optimized video file.
