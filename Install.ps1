[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SkinPath,
    [string]$RainmeterExe
)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'NerdWidgets'
if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw 'NerdWidgets folder is missing. Extract the whole ZIP first.' }
if (-not $SkinPath) {
    $config = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
    if (Test-Path -LiteralPath $config) {
        $match = Select-String -LiteralPath $config -Pattern '^SkinPath=(.+)$' | Select-Object -First 1
        if ($match) { $SkinPath = [Environment]::ExpandEnvironmentVariables($match.Matches[0].Groups[1].Value.Trim()) }
    }
    if (-not $SkinPath) { $SkinPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins' }
}
$destination = [IO.Path]::GetFullPath((Join-Path $SkinPath 'NerdWidgets'))
if ($destination.TrimEnd('\') -eq [IO.Path]::GetFullPath($source).TrimEnd('\')) { throw 'Source and installed folder must differ.' }
if ($PSCmdlet.ShouldProcess($destination, 'Install Nerd Widgets, preserving settings and history')) {
    if (Test-Path -LiteralPath $destination) {
        $backupRoot = Join-Path (Split-Path ([IO.Path]::GetFullPath($SkinPath)) -Parent) 'NerdWidgets-Backups'
        $backup = Join-Path $backupRoot (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
        New-Item -ItemType Directory -Path $backup -Force | Out-Null
        Copy-Item -LiteralPath $destination -Destination $backup -Recurse
        Write-Host "Previous version backed up to $backup"
    }
    Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($source.Length).TrimStart('\')
        $target = Join-Path $destination $relative
        $preserve = $relative -eq '@Resources\Settings.inc' -or $relative.StartsWith('@Resources\Data\')
        if (-not ($preserve -and (Test-Path -LiteralPath $target))) {
            New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        }
    }
    if (-not $RainmeterExe) { $RainmeterExe = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe' }
    if (Test-Path -LiteralPath $RainmeterExe) {
        & $RainmeterExe '!RefreshApp'
        & $RainmeterExe '!ActivateConfig' 'NerdWidgets\Settings' 'Settings.ini'
    }
    Write-Host "Installed to $destination"
}
