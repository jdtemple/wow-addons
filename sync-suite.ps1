<#
.SYNOPSIS
    Deploys LibBigginsSuite from its canonical source directory directly to the local WoW client.

.DESCRIPTION
    Propagates LibBigginsSuite.lua and suite-logo.jpg from the canonical source of truth (lib-biggins-suite/)
    directly into each installed Biggins addon in the World of Warcraft retail client (Interface\AddOns\).
    The Git addon source directories remain completely free of duplicate library files.

.PARAMETER RetailPath
    Path to the World of Warcraft retail AddOns folder. Defaults to the standard retail path.

.EXAMPLE
    .\sync-suite.ps1
#>

[CmdletBinding()]
param(
    [string]$RetailPath = "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
)

$ErrorActionPreference = 'Stop'
$rootDir = $PSScriptRoot
$sourceDir = Join-Path $rootDir 'lib-biggins-suite'

if (-not (Test-Path $sourceDir)) {
    throw "Canonical library directory not found at: $sourceDir"
}

$suiteFiles = @('LibBigginsSuite.lua', 'suite-logo.jpg')

# Verify source files exist
foreach ($file in $suiteFiles) {
    $srcPath = Join-Path $sourceDir $file
    if (-not (Test-Path $srcPath)) {
        throw "Missing canonical source file: $srcPath"
    }
}

if (-not (Test-Path $RetailPath)) {
    Write-Warning "WoW retail AddOns directory not found: $RetailPath"
    return
}

$gameAddons = @(
    'AutoJoinBiggins',
    'LazySpeedBiggins',
    'PerfBiggins',
    'SummonPetBiggins'
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Syncing LibBigginsSuite to WoW Retail Client" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

foreach ($gameAddon in $gameAddons) {
    $gameTargetDir = Join-Path $RetailPath $gameAddon
    if (Test-Path $gameTargetDir) {
        foreach ($file in $suiteFiles) {
            $src = Join-Path $sourceDir $file
            $dst = Join-Path $gameTargetDir $file
            Copy-Item -Path $src -Destination $dst -Force
            $srcHash = (Get-FileHash -Path $src -Algorithm SHA256).Hash
            $dstHash = (Get-FileHash -Path $dst -Algorithm SHA256).Hash
            if ($srcHash -eq $dstHash) {
                Write-Host "  [OK] Retail AddOns/$gameAddon/$file" -ForegroundColor Green
            } else {
                Write-Error "Hash mismatch after client sync: $dst"
            }
        }
    } else {
        Write-Warning "Addon not found in Retail AddOns: $gameAddon"
    }
}

Write-Host ""
Write-Host "LibBigginsSuite retail sync completed successfully!" -ForegroundColor Green
