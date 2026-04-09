param (
    [Parameter(Mandatory=$true)]
    [string]$InputFile
)

# ---------------------------------------------------------
# PHASE 1: SCANNING & USER SELECTION
# ---------------------------------------------------------
Write-Host "Scanning Media Information..." -ForegroundColor Cyan

# Use ffprobe to get all stream data
$ffprobeCmd = "ffprobe -v error -show_entries stream=index,codec_name,channels,codec_type -show_tags=language,title -of json ""$InputFile"""
$probeData = Invoke-Expression $ffprobeCmd | ConvertFrom-Json

$audioStreams = @()
$subStreams = @()

# Display Audio Tracks
Write-Host "`n=== AVAILABLE AUDIO TRACKS ===" -ForegroundColor Yellow
foreach ($stream in $probeData.streams | Where-Object {$_.codec_type -eq "audio"}) {
    $id = $stream.index
    $lang = if ($stream.tags.language) { $stream.tags.language } else { "und" }
    $codec = $stream.codec_name
    $ch = if ($stream.channels) { "$($stream.channels)ch" } else { "?ch" }
    $title = if ($stream.tags.title) { $stream.tags.title } else { "No Title" }
    
    Write-Host "ID: $id | Lang: $lang | Codec: $codec | $ch | Title: $title"
    $audioStreams += $stream
}

# Display Subtitle Tracks
Write-Host "`n=== AVAILABLE SUBTITLE TRACKS ===" -ForegroundColor Yellow
Write-Host "ID: 0 | SKIP ALL SUBTITLES" -ForegroundColor Gray
foreach ($stream in $probeData.streams | Where-Object {$_.codec_type -eq "subtitle"}) {
    $id = $stream.index
    $lang = if ($stream.tags.language) { $stream.tags.language } else { "und" }
    $codec = $stream.codec_name
    $title = if ($stream.tags.title) { $stream.tags.title } else { "No Title" }
    
    Write-Host "ID: $id | Lang: $lang | Codec: $codec | Title: $title"
    $subStreams += $stream
}

# User Inputs
Write-Host ""
$selectedAudioId = Read-Host "Enter the ID of the Audio Track to keep"
$selectedSubId = Read-Host "Enter the ID of the Subtitle Track to keep (or 0 for none)"

# ---------------------------------------------------------
# PHASE 2: AUDIO LOGIC (ATMOS / DTS:X CHECK)
# ---------------------------------------------------------
$selAudioStream = $audioStreams | Where-Object { $_.index -eq $selectedAudioId }
$audioCodec = $selAudioStream.codec_name
$audioAction = "copy" # Default to copying untouched

if ($audioCodec -match "truehd" -or $audioCodec -match "dts") {
    Write-Host "`nChecking selected audio for Atmos/DTS:X..." -ForegroundColor Cyan
    
    # Use MediaInfo to hunt for spatial metadata
    $miCmd = "mediainfo --Output=JSON ""$InputFile"""
    $miData = Invoke-Expression $miCmd | ConvertFrom-Json
    $hasSpatial = $false
    
    foreach ($track in $miData.media.track) {
        if ($track.StreamOrder -eq $selectedAudioId) {
            if ($track.Format_Commercial -match "Atmos" -or $track.Format_Profile -match "Atmos" -or $track.Format_Commercial -match "DTS:X" -or $track.Format_Profile -match "XLL X") {
                $hasSpatial = $true
            }
        }
    }
    
    if ($hasSpatial) {
        Write-Host "Spatial audio detected! Keeping as untouched COPY." -ForegroundColor Green
    } else {
        Write-Host "Standard lossless detected. Converting to FLAC to save space." -ForegroundColor Yellow
        $audioAction = "flac"
    }
}

# ---------------------------------------------------------
# PHASE 3: FFMPEG ENGINE (EXTRACTION & CONVERSION)
# ---------------------------------------------------------
$tempOutput = "ffmpeg_temp_output.mkv"
if (Test-Path $tempOutput) { Remove-Item $tempOutput }

# Build Subtitle map logic
$subMapFlag = ""
if ($selectedSubId -ne "0") {
    $subMapFlag = "-map 0:$selectedSubId -c:s copy -metadata:s:s:0 title="""""
} else {
    $subMapFlag = "-sn" # Explicitly drop all subtitles
}

Write-Host "`nStarting FFmpeg processing... Please wait." -ForegroundColor Cyan

# Note: By explicitly mapping ONLY the chosen video, audio, and sub streams, 
# FFmpeg inherently drops all unselected audio, unselected subs, and image attachments.
$ffmpegCmd = "ffmpeg -i ""$InputFile"" " +
             "-map 0:v:0 -c:v copy -metadata:s:v:0 language=und -metadata:s:v:0 title="""" " +
             "-map 0:$selectedAudioId -c:a $audioAction -metadata:s:a:0 title="""" " +
             "$subMapFlag " +
             "-map_chapters -1 -metadata title="""" " +
             """$tempOutput"""

# Run FFmpeg
cmd.exe /c $ffmpegCmd

# ---------------------------------------------------------
# PHASE 4: MKVTOOLNIX & FINAL NAMING
# ---------------------------------------------------------
Write-Host "`nFFmpeg process finished." -ForegroundColor Green

# Ask user for the final name
$finalFileName = Read-Host "Enter the exact name for the final video file (without the .mkv extension)"
$finalOutput = "$finalFileName.mkv"

# Rename the temp file to the user's chosen name
Rename-Item -Path $tempOutput -NewName $finalOutput

Write-Host "`nPassing to MKVToolNix to wipe global and track tags..." -ForegroundColor Cyan

# Use mkvpropedit to instantly strip the tags from the renamed file
$mkvpropCmd = "mkvpropedit ""$finalOutput"" --tags all:"
Invoke-Expression $mkvpropCmd

Write-Host "`nWorkflow Complete! Cleaned and optimized file saved as: $finalOutput" -ForegroundColor Green
