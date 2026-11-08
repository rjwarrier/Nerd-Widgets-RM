# Now Playing helper for NerdWidgets.
# Mirrors Windows' current media session (the one in the volume flyout: Spotify, browsers,
# Media Player, ...) into <Data>\nowplaying.txt as key=value lines, saves its cover art, and
# runs play/pause/next/previous commands that the card leaves in <Data>\nowplaying.cmd.
# Started hidden by the skin's RunCommand measure, which ends it when the skin closes or refreshes;
# it also exits by itself if Rainmeter is gone. Windows PowerShell 5.1, no modules.
param([string]$DataDir)
$ErrorActionPreference = 'Stop'

$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'NerdWidgetsNowPlaying', [ref]$created)
if (-not $created) { exit }

$stateFile = Join-Path $DataDir 'nowplaying.txt'
$cmdFile = Join-Path $DataDir 'nowplaying.cmd'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-State([string]$text) {
    # Written aside, then swapped in, so the card never reads half a file. .NET calls, not
    # Move-Item: the cmdlet costs tens of milliseconds of CPU per call.
    $tmp = "$stateFile.new"
    [System.IO.File]::WriteAllText($tmp, $text, $utf8)
    # [NullString]: a plain $null reaches .NET as '' and Replace rejects it.
    if ([System.IO.File]::Exists($stateFile)) { [System.IO.File]::Replace($tmp, $stateFile, [NullString]::Value) }
    else { [System.IO.File]::Move($tmp, $stateFile) }
}

try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime]
} catch {
    Write-State "status=Unavailable`nheartbeat=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`n"
    exit
}

$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1

$asStream = [System.IO.WindowsRuntimeStreamExtensions].GetMethod('AsStreamForRead', [Type[]]@([Windows.Storage.Streams.IInputStream]))

function Await($operation, [Type]$type) {
    $task = $asTask.MakeGenericMethod($type).Invoke($null, @($operation))
    if (-not $task.Wait(3000)) { return $null }
    return $task.Result
}

function Clean($value) {
    if ($null -eq $value) { return '' }
    return ([string]$value -replace '[\r\n\t]+', ' ').Trim()
}

# The current thumbnail's bytes, or $null when the player offers none.
function Read-Cover($properties) {
    if (-not $properties -or -not $properties.Thumbnail) { return $null }
    $stream = Await ($properties.Thumbnail.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
    if (-not $stream) { return $null }
    # PowerShell cannot bind the stream it gets back, so call the converter through reflection.
    $source = $asStream.Invoke($null, @($stream))
    $bytes = New-Object System.IO.MemoryStream
    try { $source.CopyTo($bytes) } finally { $source.Close() }
    $data = $bytes.ToArray()
    if ($data.Length -lt 8) { return $null }
    return , $data
}

# Every cover gets a name never used before (this run's start time plus a counter), so Rainmeter
# never shows an image it cached under the same path, even across helper restarts.
$coverRun = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$coverCount = 0
$coverFiles = New-Object System.Collections.Generic.Queue[string]
Get-ChildItem -LiteralPath $DataDir -Filter 'cover-*' | Remove-Item -Force -ErrorAction SilentlyContinue
$md5 = [System.Security.Cryptography.MD5]::Create()
function Save-Cover([byte[]]$data) {
    $extension = if ($data[0] -eq 0x89 -and $data[1] -eq 0x50) { 'png' } else { 'jpg' }
    $script:coverCount++
    $name = "cover-$coverRun-$($script:coverCount).$extension"
    [System.IO.File]::WriteAllBytes((Join-Path $DataDir $name), $data)
    # Keep the last few, since the card may still be showing the previous one.
    $coverFiles.Enqueue($name)
    while ($coverFiles.Count -gt 3) {
        try { [System.IO.File]::Delete((Join-Path $DataDir $coverFiles.Dequeue())) } catch { }
    }
    return $name
}

$parent = (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
# Held once and polled through HasExited: Get-Process each time costs milliseconds of CPU.
$parentProcess = $null
try { $parentProcess = [System.Diagnostics.Process]::GetProcessById($parent) } catch { }
$manager = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
$propertiesType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]

$last = ''
$lastWrite = [DateTime]::MinValue
$lastRead = [DateTime]::MinValue
$trackKey = ''
$cover = ''
$coverHash = ''
$trackSince = [DateTime]::UtcNow
$coverCheck = [DateTime]::MinValue
# The loop runs five times a second so buttons respond quickly; the media session is read once a
# second. FileSystemWatcher.WaitForChanged and Wait-Event were both tried and cost more CPU.
while ($true) {
    if ($parentProcess -and $parentProcess.HasExited) { break }
    $session = $null
    try { $session = $manager.GetCurrentSession() } catch { }
    $acted = $false
    if (Test-Path -LiteralPath $cmdFile) {
        $command = ''
        try { $command = [System.IO.File]::ReadAllText($cmdFile).Trim() } catch { }
        try { [System.IO.File]::Delete($cmdFile) } catch { }
        if ($session) {
            $operation = switch ($command) {
                'toggle' { $session.TryTogglePlayPauseAsync() }
                'next' { $session.TrySkipNextAsync() }
                'prev' { $session.TrySkipPreviousAsync() }
                default { $null }
            }
            if ($operation) {
                try { $null = Await $operation ([bool]) } catch { }
                $acted = $true
                Start-Sleep -Milliseconds 300
            }
        }
    }
    if ($acted -or ([DateTime]::UtcNow - $lastRead).TotalMilliseconds -ge 950) {
        $lastRead = [DateTime]::UtcNow
        $lines = New-Object System.Collections.Generic.List[string]
        try {
            if ($session) {
                $properties = Await ($session.TryGetMediaPropertiesAsync()) $propertiesType
                $info = $session.GetPlaybackInfo()
                $timeline = $session.GetTimelineProperties()
                $title = Clean $properties.Title
                $artist = Clean $properties.Artist
                if (-not $artist) { $artist = Clean $properties.AlbumArtist }
                $app = Clean $session.SourceAppUserModelId
                $key = "$app|$title|$artist"
                if ($key -ne $trackKey) { $trackKey = $key; $trackSince = [DateTime]::UtcNow }
                # Players often publish the new title while still offering the old cover, and some
                # change the cover later. So the thumbnail is read every second for 10 s after a
                # track change, then every 15 s; a file is written only when the image changes.
                $now = [DateTime]::UtcNow
                if (($now - $trackSince).TotalSeconds -lt 10 -or ($now - $coverCheck).TotalSeconds -ge 15) {
                    $coverCheck = $now
                    try {
                        $data = Read-Cover $properties
                        if (-not $data) { $cover = ''; $coverHash = '' }
                        else {
                            $hash = [BitConverter]::ToString($md5.ComputeHash($data))
                            if ($hash -ne $coverHash) { $cover = Save-Cover $data; $coverHash = $hash }
                        }
                    } catch { }
                }
                $duration = ($timeline.EndTime - $timeline.StartTime).TotalSeconds
                $position = ($timeline.Position - $timeline.StartTime).TotalSeconds
                $lines.Add("app=$app")
                $lines.Add("title=$title")
                $lines.Add("artist=$artist")
                $lines.Add("album=$(Clean $properties.AlbumTitle)")
                $lines.Add("status=$($info.PlaybackStatus)")
                $lines.Add("canNext=$([int]$info.Controls.IsNextEnabled)")
                $lines.Add("canPrev=$([int]$info.Controls.IsPreviousEnabled)")
                $lines.Add("cover=$cover")
                if ($duration -gt 0) {
                    $lines.Add("duration=$([math]::Round($duration))")
                    $lines.Add("position=$([math]::Round($position))")
                    $lines.Add("updated=$($timeline.LastUpdatedTime.ToUnixTimeSeconds())")
                }
            } else {
                $trackKey = ''; $cover = ''; $coverHash = ''
                $lines.Add('status=Closed')
            }
        } catch {
            $lines.Clear()
            $lines.Add('status=Closed')
        }
        $text = ($lines -join "`n")
        # Rewrite on change, and every few seconds anyway as a heartbeat.
        if ($text -ne $last -or ([DateTime]::UtcNow - $lastWrite).TotalSeconds -ge 5) {
            try {
                Write-State ($text + "`nheartbeat=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`n")
                $last = $text
                $lastWrite = [DateTime]::UtcNow
            } catch { }
        }
    }
    Start-Sleep -Milliseconds 200
}
