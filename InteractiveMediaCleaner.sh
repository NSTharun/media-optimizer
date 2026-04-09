#!/bin/bash

# 1. Take input from argument or prompt
InputFile="$1"
if [ -z "$InputFile" ]; then
    read -p "Enter the path to the input video file: " InputFile
fi

# Clean the path (Removes accidental single/double quotes if you drag-and-drop the file into terminal)
CleanPath=$(echo "$InputFile" | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//')

# ---------------------------------------------------------
# PHASE 1: SCANNING & USER SELECTION
# ---------------------------------------------------------
echo -e "\e[36m\nScanning Media Information...\e[0m"

# Use ffprobe to get JSON stream data
probeData=$(ffprobe -v error -show_streams -of json "$CleanPath")

echo -e "\e[33m\n=== AVAILABLE AUDIO TRACKS ===\e[0m"
# Parse JSON with jq and read line by line
while read -r stream; do
    id=$(echo "$stream" | jq -r '.index')
    lang=$(echo "$stream" | jq -r '.tags.language // "und"')
    codec=$(echo "$stream" | jq -r '.codec_name')
    ch=$(echo "$stream" | jq -r '.channels // "?"')
    title=$(echo "$stream" | jq -r '.tags.title // "No Title"')
    
    echo "ID: $id | Lang: $lang | Codec: $codec | ${ch}ch | Title: $title"
done < <(echo "$probeData" | jq -c '.streams[] | select(.codec_type == "audio")')

echo -e "\e[33m\n=== AVAILABLE SUBTITLE TRACKS ===\e[0m"
echo -e "\e[90mID: 0 | SKIP ALL SUBTITLES\e[0m"
while read -r stream; do
    id=$(echo "$stream" | jq -r '.index')
    lang=$(echo "$stream" | jq -r '.tags.language // "und"')
    codec=$(echo "$stream" | jq -r '.codec_name')
    title=$(echo "$stream" | jq -r '.tags.title // "No Title"')
    
    echo "ID: $id | Lang: $lang | Codec: $codec | Title: $title"
done < <(echo "$probeData" | jq -c '.streams[] | select(.codec_type == "subtitle")')

# User Inputs
echo ""
read -p "Enter the ID of the Audio Track to keep: " selectedAudioId
read -p "Enter the ID of the Subtitle Track to keep (or 0 for none): " selectedSubId

# ---------------------------------------------------------
# PHASE 2: AUDIO LOGIC (ATMOS / DTS:X CHECK)
# ---------------------------------------------------------
audioCodec=$(echo "$probeData" | jq -r --arg id "$selectedAudioId" '.streams[] | select(.index == ($id|tonumber)) | .codec_name')
audioAction="copy"

if [[ "$audioCodec" == *"truehd"* || "$audioCodec" == *"dts"* ]]; then
    echo -e "\e[36m\nChecking selected audio for Atmos/DTS:X...\e[0m"
    
    miData=$(mediainfo --Output=JSON "$CleanPath")
    
    # jq filter to check Format_Commercial and Format_Profile for spatial keywords
    hasSpatial=$(echo "$miData" | jq -r --arg id "$selectedAudioId" '
        [.media.track[]? | select((.StreamOrder | tostring) == $id) |
        ( (.Format_Commercial // "") | test("Atmos|DTS:X"; "i") ) or
        ( (.Format_Profile // "") | test("Atmos|XLL X"; "i") )] | any
    ')
    
    if [ "$hasSpatial" == "true" ]; then
        echo -e "\e[32mSpatial audio detected! Keeping as untouched COPY.\e[0m"
    else
        echo -e "\e[33mStandard lossless detected. Converting to FLAC to save space.\e[0m"
        audioAction="flac"
    fi
fi

# ---------------------------------------------------------
# PHASE 3: FFMPEG ENGINE (EXTRACTION & CONVERSION)
# ---------------------------------------------------------
tempOutput="ffmpeg_temp_output.mkv"
rm -f "$tempOutput"

echo -e "\e[36m\nStarting FFmpeg processing... Please wait.\e[0m"

# Build FFmpeg arguments safely using a bash array
ffmpeg_args=(
    "-i" "$CleanPath"
    "-map" "0:v:0" "-c:v" "copy" "-metadata:s:v:0" "language=und" "-metadata:s:v:0" "title="
    "-map" "0:$selectedAudioId" "-c:a" "$audioAction" "-metadata:s:a:0" "title="
)

if [ "$selectedSubId" != "0" ]; then
    ffmpeg_args+=("-map" "0:$selectedSubId" "-c:s" "copy" "-metadata:s:s:0" "title=")
else
    ffmpeg_args+=("-sn") # Explicitly drop all subtitles
fi

# Drop chapters and global title, output to temp file
ffmpeg_args+=("-map_chapters" "-1" "-metadata" "title=" "$tempOutput")

# Run FFmpeg
ffmpeg "${ffmpeg_args[@]}"

# ---------------------------------------------------------
# PHASE 4: MKVTOOLNIX & FINAL NAMING
# ---------------------------------------------------------
echo -e "\e[32m\nFFmpeg process finished.\e[0m"

read -p "Enter the exact name for the final video file (without the .mkv extension): " finalFileName
finalOutput="${finalFileName}.mkv"

mv "$tempOutput" "$finalOutput"

echo -e "\e[36m\nPassing to MKVToolNix to wipe global and track tags...\e[0m"

mkvpropedit "$finalOutput" --tags all: --delete-track-statistics-tags

echo -e "\e[32m\nWorkflow Complete! Cleaned and optimized file saved as: $finalOutput\e[0m"
