#!/bin/bash

# 1. Take input from argument or prompt
InputFile="$1"
if [ -z "$InputFile" ]; then
    read -p "Enter the path to the input video file: " InputFile
fi

# Clean the path
CleanPath=$(echo "$InputFile" | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//')

# ---------------------------------------------------------
# PHASE 1: SCANNING & USER SELECTION
# ---------------------------------------------------------
echo -e "\e[36m\nScanning Media Information...\e[0m"

probeData=$(ffprobe -v error -show_streams -of json "$CleanPath")

echo -e "\e[33m\n=== AVAILABLE AUDIO TRACKS ===\e[0m"
while read -r stream; do
    id=$(echo "$stream" | jq -r '.index')
    lang=$(echo "$stream" | jq -r '.tags.language // "und"')
    codec=$(echo "$stream" | jq -r '.codec_name')
    ch=$(echo "$stream" | jq -r '.channels // "?"')
    echo "ID: $id | Lang: $lang | Codec: $codec | ${ch}ch"
done < <(echo "$probeData" | jq -c '.streams[] | select(.codec_type == "audio")')

echo -e "\e[33m\n=== AVAILABLE SUBTITLE TRACKS ===\e[0m"
echo -e "\e[90mID: 0 | SKIP ALL SUBTITLES\e[0m"
while read -r stream; do
    id=$(echo "$stream" | jq -r '.index')
    lang=$(echo "$stream" | jq -r '.tags.language // "und"')
    codec=$(echo "$stream" | jq -r '.codec_name')
    echo "ID: $id | Lang: $lang | Codec: $codec"
done < <(echo "$probeData" | jq -c '.streams[] | select(.codec_type == "subtitle")')

echo ""
read -p "Enter the ID of the Audio Track to keep: " selectedAudioId
read -p "Enter the ID of the Subtitle Track to keep (or 0 for none): " selectedSubId

# ---------------------------------------------------------
# PHASE 2: AUDIO LOGIC (Spatial Check)
# ---------------------------------------------------------
audioCodec=$(echo "$probeData" | jq -r --arg id "$selectedAudioId" '.streams[] | select(.index == ($id|tonumber)) | .codec_name')
audioAction="copy"

if [[ "$audioCodec" == *"truehd"* || "$audioCodec" == *"dts"* ]]; then
    echo -e "\e[36m\nChecking selected audio for Atmos/DTS:X...\e[0m"
    miData=$(mediainfo --Output=JSON "$CleanPath")
    hasSpatial=$(echo "$miData" | jq -r --arg id "$selectedAudioId" '
        [.media.track[]? | select((.StreamOrder | tostring) == $id) |
        ( (.Format_Commercial // "") | test("Atmos|DTS:X"; "i") ) or
        ( (.Format_Profile // "") | test("Atmos|XLL X"; "i") )] | any
    ')
    
    if [ "$hasSpatial" != "true" ]; then
        echo -e "\e[33mStandard lossless detected. Converting to FLAC to save space.\e[0m"
        audioAction="flac"
    else
        echo -e "\e[32mSpatial audio detected! Keeping as untouched COPY.\e[0m"
    fi
fi

# ---------------------------------------------------------
# PHASE 3: FFMPEG STREAM SCRUBBING
# ---------------------------------------------------------
tempFFmpeg="temp_ffmpeg.mkv"
rm -f "$tempFFmpeg"

echo -e "\e[36m\nStep 1: FFmpeg is stripping bloat while preserving language...\e[0m"

# Build arguments: Preserves language by NOT setting language=und for audio/subs
ffmpeg_args=(
    "-i" "$CleanPath"
    "-map" "0:v:0" "-c:v" "copy" "-metadata:s:v:0" "title=" "-metadata:s:v:0" "language=und"
    "-map" "0:$selectedAudioId" "-c:a" "$audioAction" "-metadata:s:a:0" "title="
)

if [ "$selectedSubId" != "0" ]; then
    ffmpeg_args+=("-map" "0:$selectedSubId" "-c:s" "copy" "-metadata:s:s:0" "title=")
else
    ffmpeg_args+=("-sn")
fi

# Scrubbing: No chapters, No global metadata, No global title
ffmpeg_args+=("-map_chapters" "-1" "-metadata" "title=" "-map_metadata" "-1" "$tempFFmpeg")

ffmpeg "${ffmpeg_args[@]}"

# ---------------------------------------------------------
# PHASE 4: MKVMERGE FINAL POLISH
# ---------------------------------------------------------
echo -e "\e[32m\nStep 1 Complete.\e[0m"
read -p "Enter the exact name for the final video file (without .mkv): " finalFileName
finalOutput="${finalFileName}.mkv"

echo -e "\e[36m\nStep 2: MKVMerge is performing a fresh remux for container optimization...\e[0m"

subFlag=""
if [ "$selectedSubId" != "0" ]; then
    subFlag="--default-track 0:yes"
fi

# Fresh Remux: Wipes global tags, track tags, attachments, and updates FLAC info
mkvmerge -o "$finalOutput" --no-global-tags --no-track-tags --no-attachments --title "" $subFlag "$tempFFmpeg"

# Cleanup
rm -f "$tempFFmpeg"

echo -e "\e[32m\nWorkflow Complete! All metadata fields scrubbed and track flags updated.\e[0m"
