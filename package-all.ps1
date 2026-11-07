<#
.SYNOPSIS
    Packages all Biggins AddOns for CurseForge, Wago, and local installation.

.DESCRIPTION
    Iterates through all 6 suite addons in C:\Code\wow-addons, invokes their respective
    package.ps1 build scripts, generates release ZIP archives in each addon's dist/ folder,
    and optionally synchronizes all release packages directly into the local World of Warcraft
    retail AddOns directory.

.PARAMETER Install
    Copies the staged addons directly into the local World of Warcraft retail AddOns directory.

.EXAMPLE
    .\package-all.ps1
    .\package-all.ps1 -Install
#>

[CmdletBinding()]
param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$rootDir = $PSScriptRoot

$addons = @(
    'angler-biggins',
    'autojoin-biggins',
    'chatlink-biggins',
    'lazyspeed-biggins',
    'perf-biggins',
    'saferelease-biggins',
    'summonpet-biggins'
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Biggins AddOns - Master Suite Packager" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
if ($Install) {
    Write-Host "Mode: Build Release ZIPs & Install to Retail Client" -ForegroundColor Yellow
} else {
    Write-Host "Mode: Build Release ZIPs only (dist/)" -ForegroundColor Yellow
}
Write-Host ""

$results = @()

foreach ($addonName in $addons) {
    $addonDir = Join-Path $rootDir $addonName
    $packageScript = Join-Path $addonDir 'package.ps1'

    if (-not (Test-Path $packageScript)) {
        Write-Warning "Package script not found: $packageScript"
        continue
    }

    Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Building $addonName..." -ForegroundColor White

    # Invoke addon packager with or without -Install switch
    if ($Install) {
        & $packageScript -Install
    } else {
        & $packageScript
    }

    # Find the newly created zip in dist
    $distDir = Join-Path $addonDir 'dist'
    if (Test-Path $distDir) {
        $latestZip = Get-ChildItem -Path $distDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestZip) {
            $sizeKB = [math]::Round($latestZip.Length / 1KB, 2)
            $results += [PSCustomObject]@{
                Addon   = $addonName
                ZipFile = $latestZip.Name
                SizeKB  = "$sizeKB KB"
                Status  = "Success"
            }
        }
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Master Packaging Complete!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
$results | Format-Table -AutoSize
