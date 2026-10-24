<#
.SYNOPSIS
    Packages ChatLink Biggins for CurseForge, Wago, and local installation.

.DESCRIPTION
    Dynamically extracts the version from ChatLinkBiggins.toc, stages required release
    files into an inner 'ChatLinkBiggins/' folder, pulls the latest canonical suite
    library from lib-biggins-suite/, compresses into dist/ChatLinkBiggins-v<version>.zip,
    and optionally syncs directly to the World of Warcraft retail AddOns folder.

.PARAMETER Install
    Copies the staged addon directly into the local World of Warcraft retail AddOns directory.

.EXAMPLE
    .\package.ps1
    .\package.ps1 -Install
#>

[CmdletBinding()]
param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$addonDir = $PSScriptRoot
$tocPath = Join-Path $addonDir 'ChatLinkBiggins.toc'

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

Write-Host "Packaging ChatLink Biggins v$version for release..." -ForegroundColor Cyan

$distDir = Join-Path $addonDir 'dist'
$stagingDir = Join-Path $distDir 'ChatLinkBiggins'
$zipFileName = "ChatLinkBiggins-v$version.zip"
$zipPath = Join-Path $distDir $zipFileName

# Ensure clean staging directory
if (Test-Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# Copy release files
$releaseFiles = @('ChatLinkBiggins.lua', 'ChatLinkBiggins.toc', 'logo.jpg', 'README.md', 'CHANGELOG.md')
foreach ($file in $releaseFiles) {
    $sourcePath = Join-Path $addonDir $file
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $stagingDir -Force
    } else {
        Write-Warning "File not found: $sourcePath"
    }
}

# Pull shared suite library and assets from canonical source of truth into staging
$canonicalSuiteDir = Join-Path (Split-Path $addonDir -Parent) 'lib-biggins-suite'
if (Test-Path $canonicalSuiteDir) {
    Copy-Item (Join-Path $canonicalSuiteDir 'LibBigginsSuite.lua') $stagingDir -Force
    Copy-Item (Join-Path $canonicalSuiteDir 'suite-logo.jpg') $stagingDir -Force
} else {
    Write-Warning "Canonical suite directory not found: $canonicalSuiteDir"
}

# Optional local installation to WoW client
$wowAddonDir = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\ChatLinkBiggins"
if ($Install) {
    Write-Host "Installing to WoW retail client: $wowAddonDir" -ForegroundColor Yellow
    if (Test-Path $wowAddonDir) {
        Remove-Item -Path $wowAddonDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $wowAddonDir -Force | Out-Null
    Copy-Item -Path (Join-Path $stagingDir '*') -Destination $wowAddonDir -Recurse -Force
    Write-Host "Successfully installed to WoW retail client!" -ForegroundColor Green
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
