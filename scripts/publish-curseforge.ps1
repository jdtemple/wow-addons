<#
.SYNOPSIS
    Packages and publishes a Biggins addon to CurseForge via their Upload REST API.

.DESCRIPTION
    Runs the addon's package.ps1 to produce a release zip in dist/, extracts the latest
    section from CHANGELOG.md, builds the metadata payload, and uploads to CurseForge.
    Supports -DryRun for full local verification without uploading.

.PARAMETER Addon
    Directory name of the addon (e.g. "perf-biggins", "lazyspeed-biggins").

.PARAMETER ReleaseType
    Release channel ("release", "beta", or "alpha"). Default: "release".

.PARAMETER ApiKey
    CurseForge API Token. Defaults to $env:CF_API_KEY.

.PARAMETER GameVersions
    Optional array of numeric CurseForge game version IDs. If omitted, queries API.

.PARAMETER DryRun
    Packages the addon and displays the exact upload payload without contacting CurseForge.

.EXAMPLE
    .\scripts\publish-curseforge.ps1 -Addon "perf-biggins" -DryRun
    .\scripts\publish-curseforge.ps1 -Addon "perf-biggins" -ReleaseType "release"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Addon,

    [ValidateSet("release", "beta", "alpha")]
    [string]$ReleaseType = "release",

    [string]$ApiKey = $env:CF_API_KEY,

    [int[]]$GameVersions = @(),

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$configPath = Join-Path $PSScriptRoot "addons-config.json"

if (-not (Test-Path $configPath)) {
    throw "Addons configuration file not found at: $configPath"
}

$config = Get-Content -Path $configPath -Raw -Encoding utf8 | ConvertFrom-Json
$addonsMap = if ($config.addons) { $config.addons } else { $config }
if (-not $addonsMap.PSObject.Properties[$Addon]) {
    throw "Addon '$Addon' not defined in addons-config.json. Valid addons: $($addonsMap.PSObject.Properties.Name -join ', ')"
}

$addonMeta = $addonsMap.$Addon
$projectId = $addonMeta.projectId
$addonName = $addonMeta.name
$addonDir = Join-Path $repoRoot $Addon

Write-Host "============================================================"
Write-Host "Publishing: $addonName ($Addon)"
Write-Host "CurseForge Project ID: $projectId"
Write-Host "Release Type: $ReleaseType"
Write-Host "============================================================"

# 1. Execute addon's package.ps1
$pkgScript = Join-Path $addonDir "package.ps1"
if (-not (Test-Path $pkgScript)) {
    throw "Packaging script not found at: $pkgScript"
}

Write-Host "Executing packaging script: $pkgScript"
& $pkgScript
if (-not $?) {
    throw "Packaging script execution failed."
}

# 2. Locate generated zip in dist/
$distDir = Join-Path $addonDir "dist"
if (-not (Test-Path $distDir)) {
    throw "Dist directory does not exist at: $distDir"
}

$zipFile = Get-ChildItem -Path $distDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $zipFile) {
    throw "No .zip file found in $distDir"
}

Write-Host "Release Zip: $($zipFile.FullName) ($([math]::Round($zipFile.Length / 1KB, 2)) KB)"

# Extract version from TOC for Git tagging and display
$tocFile = Get-ChildItem -Path $addonDir -Filter "*.toc" | Select-Object -First 1
$version = ""
if ($tocFile) {
    $tocContent = Get-Content -Path $tocFile.FullName -Raw -Encoding utf8
    if ($tocContent -match '(?m)^##\s*Version:\s*([^

]+)') {
        $version = $matches[1].Trim()
    }
}
if (-not $version -and $zipFile.BaseName -match '-v?([0-9]+\.[0-9]+(?:\.[0-9]+)?)') {
    $version = $matches[1]
}
$tagName = if ($version) { "$Addon-$version" } else { "" }
Write-Host "Addon Version: $version (Git Tag: $tagName)"

# 3. Read CHANGELOG.md verbatim (1:1 with CurseForge release changelog)
$changelogPath = Join-Path $addonDir "CHANGELOG.md"
if (Test-Path $changelogPath) {
    $changelogText = (Get-Content -Path $changelogPath -Raw -Encoding utf8).Trim()
    Write-Host "Loaded CHANGELOG.md verbatim ($($changelogText.Length) chars)."
} else {
    $changelogText = "$addonName $ReleaseType release."
    Write-Warning "No CHANGELOG.md found; using fallback description."
}

# 4. Resolve Game Versions (Per-addon override or suite-wide supportedGameVersions)
$targetVersionStrings = if ($addonMeta.supportedGameVersions) {
    @($addonMeta.supportedGameVersions)
} elseif ($config.supportedGameVersions) {
    @($config.supportedGameVersions)
} else {
    @("12.1.7", "12.1.5")
}
$resolvedVersions = @()

if ($GameVersions.Count -gt 0) {
    $resolvedVersions = $GameVersions
} elseif (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
    try {
        Write-Host "Querying CurseForge API for Retail game versions: $($targetVersionStrings -join ', ')..."
        $cfVersions = Invoke-RestMethod -Uri "https://wow.curseforge.com/api/game/versions" -Headers @{ "X-Api-Token" = $ApiKey } -Method Get
        # Strictly filter for World of Warcraft Retail (gameVersionTypeID 517)
        $retailVersions = $cfVersions | Where-Object { $_.gameVersionTypeID -eq 517 }

        # Match ONLY the versions in our strict whitelist
        foreach ($verStr in $targetVersionStrings) {
            $match = $retailVersions | Where-Object { $_.name -eq $verStr } | Select-Object -First 1
            if ($match) {
                $resolvedVersions += $match.id
                Write-Host "Matched Retail game version: $verStr (CurseForge ID: $($match.id))"
            } else {
                Write-Warning "CurseForge does not currently list version '$verStr' under Retail; skipping."
            }
        }
    } catch {
        Write-Warning "Could not fetch game versions from CurseForge API: $_"
    }
}

# Fallback for local DryRun when no API key is present
if ($resolvedVersions.Count -eq 0) {
    Write-Host "DryRun / local mode: Targeted versions = $($targetVersionStrings -join ', ')"
    $resolvedVersions = @(12107, 12105)
}

# 5. Build Metadata JSON
$metadataObj = [ordered]@{
    changelog = $changelogText
    changelogType = "markdown"
    displayName = $zipFile.BaseName
    gameVersions = $resolvedVersions
    releaseType = $ReleaseType
}

$metadataJson = $metadataObj | ConvertTo-Json -Compress

if ($DryRun) {
    Write-Host "`n--- [DRY RUN: METADATA PAYLOAD] ---"
    Write-Host ($metadataObj | ConvertTo-Json -Depth 5)
    Write-Host "--- [DRY RUN: TARGET ENDPOINT] ---"
    Write-Host "POST https://wow.curseforge.com/api/projects/$projectId/upload-file"
    Write-Host "--- [DRY RUN: FILE ATTACHMENT] ---"
    Write-Host "$($zipFile.FullName)"
    Write-Host "--- [DRY RUN: GIT TAG] ---"
    Write-Host "Tag to create and push: $tagName"
    Write-Host "`n[DRY RUN COMPLETE] No network requests were made to CurseForge."
    # Clean up local zip so working tree remains pristine
    if (Test-Path $zipFile.FullName) {
        Remove-Item -Path $zipFile.FullName -Force -ErrorAction SilentlyContinue
    }
    return
}

# 6. Upload via curl.exe
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "CurseForge API Key is required for publishing. Set CF_API_KEY environment variable or pass -ApiKey."
}

$uploadUrl = "https://wow.curseforge.com/api/projects/$projectId/upload-file"
Write-Host "Uploading to CurseForge: $uploadUrl"

$tempMetaFile = Join-Path $distDir "metadata.json"
$metadataJson | Out-File -FilePath $tempMetaFile -Encoding utf8 -NoNewline

try {
    $response = & curl.exe -s -S -X POST $uploadUrl `
        -H "X-Api-Token: $ApiKey" `
        -F "metadata=<$tempMetaFile;type=application/json" `
        -F "file=@$($zipFile.FullName)"

    Write-Host "CurseForge API Response: $response"
    if ($response -match '"id"\s*:\s*(\d+)') {
        Write-Host "Successfully published $addonName! CurseForge File ID: $($matches[1])"
    } elseif ($response -match 'error' -or $response -match 'message') {
        throw "CurseForge API returned an error: $response"
    } else {
        Write-Host "Upload completed with response: $response"
    }

    # 7. Create & Push Git Tag on Successful Upload
    if ($tagName) {
        try {
            Write-Host "Checking if Git tag '$tagName' already exists on remote..."
            $remoteTag = git ls-remote --tags origin "refs/tags/$tagName" 2>$null
            if ([string]::IsNullOrWhiteSpace($remoteTag)) {
                Write-Host "Creating Git tag: $tagName"
                git tag $tagName
                git push origin "refs/tags/$tagName"
                Write-Host "Successfully pushed Git tag '$tagName' to GitHub!"
            } else {
                Write-Host "Git tag '$tagName' already exists on remote; skipping."
            }
        } catch {
            Write-Warning "Failed to create/push Git tag '$tagName': $_"
        }
    }
} finally {
    if (Test-Path $tempMetaFile) {
        Remove-Item -Path $tempMetaFile -Force -ErrorAction SilentlyContinue
    }
}
