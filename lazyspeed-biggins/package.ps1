<#
.SYNOPSIS
    Packages LazySpeed Biggins for CurseForge and Wago releases.

.DESCRIPTION
    Dynamically extracts the version from LazySpeedBiggins.toc, stages required release
    files into an inner 'LazySpeedBiggins/' folder (required by WoW addon managers),
    compresses into dist/LazySpeedBiggins-v<version>.zip, and cleans up the staging area.

.EXAMPLE
    .\package.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$addonDir = $PSScriptRoot
$tocPath = Join-Path $addonDir 'LazySpeedBiggins.toc'

if (-not (Test-Path $tocPath)) {
    throw "Cannot find TOC file at: $tocPath"
}

# Extract version from TOC
$tocContent = Get-Content -Path $tocPath -Raw
if ($tocContent -match '(?m)^##\s*Version:\s*([^\r\n]+)') {
    $version = $matches[1].Trim()
} else {
    throw "Could not determine version from $tocPath"
}

Write-Host "Packaging LazySpeed Biggins v$version for release..." -ForegroundColor Cyan

$distDir = Join-Path $addonDir 'dist'
$stagingDir = Join-Path $distDir 'LazySpeedBiggins'
$zipFileName = "LazySpeedBiggins-v$version.zip"
$zipPath = Join-Path $distDir $zipFileName

# Ensure clean staging directory
if (Test-Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# Copy release files
$releaseFiles = @('LazySpeedBiggins.lua', 'LazySpeedBiggins.toc', 'README.md', 'CHANGELOG.md')
foreach ($file in $releaseFiles) {
    $sourcePath = Join-Path $addonDir $file
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $stagingDir -Force
    } else {
        Write-Warning "File not found: $sourcePath"
    }
}

# Compress to ZIP
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}
Compress-Archive -Path $stagingDir -DestinationPath $zipPath -Force

# Clean up uncompressed staging folder
Remove-Item -Path $stagingDir -Recurse -Force

# Report results
$zipItem = Get-Item $zipPath
$sizeKB = [math]::Round($zipItem.Length / 1KB, 2)

Write-Host ""
Write-Host "Package created successfully!" -ForegroundColor Green
Write-Host "  File: $zipFileName"
Write-Host "  Size: $sizeKB KB"
Write-Host "  Path: $zipPath"
Write-Host ""
Write-Host "Ready to upload to CurseForge / Wago." -ForegroundColor Yellow
