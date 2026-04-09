param (
    [Parameter(Mandatory=$true)]
    [string]$InputFile
)

$CleanPath = $InputFile.Trim("`"").Trim("'")

# --- PHASE 1: SCANNING ---
Write-Host "`nScanning Media Information..." -ForegroundColor Cyan
$ffprobeCmd = "ffprobe -v error -show_streams -of json `"$CleanPath`""
$probeData = cmd.exe /c $ffprobeCmd | ConvertFrom-Json

$audioStreams = @(); $subStreams = @()

Write-Host "`n=== AVAILABLE AUDIO TRACKS ===" -ForegroundColor Yellow
foreach ($stream in $probeData.streams | Where-Object {$_.codec_type -eq "audio"}) {
    $id = $stream.index
    $lang = if ($stream.tags.language) { $stream.tags.language } else { "und" }
    $codec = $stream.codec_name
    $ch = if ($stream.channels) { "$($stream.channels)ch" } else { "?ch" }
    Write-Host "ID: $id | Lang: $lang | Codec: $codec | $ch"
    $audioStreams += $stream
}

Write-Host "`n=== AVAILABLE SUBTITLE TRACKS ===" -ForegroundColor Yellow
Write-Host "ID: 0 | SKIP ALL SUBTITLES" -ForegroundColor Gray
foreach ($stream in $probeData.streams | Where-Object {$_.codec_type -eq "subtitle"}) {
    $lang = if ($stream.tags.language) { $stream.tags.language } else { "und" }
    Write-Host "ID: $($stream.index) | Lang: $lang | Codec: $($stream.codec_name)"
    $subStreams += $stream
}

$selectedAudioId = Read-Host "`nEnter the ID of the Audio Track to keep"
$selectedSubId = Read-Host "Enter the ID of the Subtitle Track to keep (or 0 for none)"

# --- PHASE 2: AUDIO LOGIC ---
$selAudioStream = $audioStreams | Where-Object { $_.index -eq $selectedAudioId }
$audioCodec = $selAudioStream.codec_name
$audioAction = "copy"

if ($audioCodec -match "truehd" -or $audioCodec -match "dts") {
    $miCmd = "mediainfo --Output=JSON `"$CleanPath`""
    $miData = cmd.exe /c $miCmd | ConvertFrom-Json
    $hasSpatial = $false
    foreach ($track in $miData.media.track) {
        if ($track.StreamOrder -eq $selectedAudioId) {
            if ($track.Format_Commercial -match "Atmos" -or $track.Format_Profile -match "Atmos" -or $track.Format_Commercial -match "DTS:X") { $hasSpatial = $true }
        }
    }
    if (-not $hasSpatial) { $audioAction = "flac" }
}

# --- PHASE 3: FFMPEG STREAM SCRUBBING ---
$tempFFmpeg = "temp_ffmpeg.mkv"
if (Test-Path $tempFFmpeg) { Remove-Item $tempFFmpeg }

# Subtitle Logic: Map the stream, clear the title, but DO NOT touch the language
$subMap = if ($selectedSubId -ne "0") { "-map 0:$selectedSubId -c:s copy -metadata:s:s:0 title=`"`"" } else { "-sn" }

Write-Host "`nStep 1: FFmpeg is stripping bloat while preserving language..." -ForegroundColor Cyan

# We removed "language=und" for Audio and Subtitles to preserve the original tags.
$ffmpegCmd = "ffmpeg -i `"$CleanPath`" " +
             "-map 0:v:0 -c:v copy -metadata:s:v:0 title=`"`" -metadata:s:v:0 language=und " +
             "-map 0:$selectedAudioId -c:a $audioAction -metadata:s:a:0 title=`"`" " +
             "$subMap " +
             "-map_chapters -1 -metadata title=`"`" -map_metadata -1 `"$tempFFmpeg`""
cmd.exe /c $ffmpegCmd

# --- PHASE 4: MKVMERGE FINAL POLISH ---
Write-Host "`nStep 2: MKVMerge is performing a fresh remux for container optimization..." -ForegroundColor Green
$finalName = Read-Host "`nEnter final filename (without .mkv)"
$finalOutput = "$finalName.mkv"

$subFlag = if ($selectedSubId -ne "0") { "--default-track 0:yes" } else { "" }

$mkvmergeCmd = "mkvmerge -o `"$finalOutput`" --no-global-tags --no-track-tags --no-attachments --title `"`" $subFlag `"$tempFFmpeg`""
cmd.exe /c $mkvmergeCmd

if (Test-Path $tempFFmpeg) { Remove-Item $tempFFmpeg }

Write-Host "`nWorkflow Complete! Bloat removed, Languages preserved!" -ForegroundColor Green
