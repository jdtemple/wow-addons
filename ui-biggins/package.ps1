<#
.SYNOPSIS
    Packages UI Biggins for CurseForge, Wago, and local installation.

.DESCRIPTION
    Dynamically extracts the version from UIBiggins.toc, stages required release
    files into an inner 'UIBiggins/' folder, pulls the latest canonical suite
    library from lib-biggins-suite/, compresses into dist/UIBiggins-v<version>.zip,
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
$tocPath = Join-Path $addonDir 'UIBiggins.toc'

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

Write-Host "Packaging UI Biggins v$version for release..." -ForegroundColor Cyan

$distDir = Join-Path $addonDir 'dist'
$stagingDir = Join-Path $distDir 'UIBiggins'
$zipFileName = "UIBiggins-v$version.zip"
$zipPath = Join-Path $distDir $zipFileName

# Ensure clean staging directory
if (Test-Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# Copy root release files
$releaseFiles = @('UIBiggins.lua', 'UIBiggins.toc', 'logo.jpg', 'README.md', 'CHANGELOG.md', 'description.md')
foreach ($file in $releaseFiles) {
    $sourcePath = Join-Path $addonDir $file
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination $stagingDir -Force
    } else {
        Write-Warning "File not found: $sourcePath"
    }
}

# Copy subdirectories (Core, Modules)
$subDirs = @('Core', 'Modules', 'Fonts')
foreach ($dir in $subDirs) {
    $sourceDir = Join-Path $addonDir $dir
    if (Test-Path $sourceDir) {
        $destDir = Join-Path $stagingDir $dir
        Copy-Item -Path $sourceDir -Destination $stagingDir -Recurse -Force
    }
}

# Pull shared suite library and assets from canonical source of truth into staging
$canonicalSuiteDir = Join-Path (Split-Path $addonDir -Parent) 'lib-biggins-suite'
if (Test-Path $canonicalSuiteDir) {
    Copy-Item (Join-Path $canonicalSuiteDir 'LibBigginsSuite.lua') $stagingDir -Force
    if (Test-Path (Join-Path $canonicalSuiteDir 'suite-logo.jpg')) {
        Copy-Item (Join-Path $canonicalSuiteDir 'suite-logo.jpg') $stagingDir -Force
    }
} else {
    Write-Warning "Canonical suite directory not found: $canonicalSuiteDir"
}

# Optional local installation to WoW client
$wowAddonDir = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\UIBiggins"
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
Write-Host "Ready to upload to CurseForge / Wago." -ForegroundColor Cyan
