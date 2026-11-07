<#
.SYNOPSIS
    Detects which Biggins addons were modified and need to be published.

.DESCRIPTION
    Inspects changed files in git. If the shared library (lib-biggins-suite/)
    was modified, all addons are selected for publishing. Otherwise, only
    the specific addons with changes are selected.
    Supports manual target selection via workflow_dispatch.

.PARAMETER ManualTarget
    Explicit target from workflow_dispatch (e.g. "all", "perf-biggins").

.PARAMETER BaseRef
    Git reference or commit SHA to compare against (defaults to HEAD~1).

.PARAMETER Local
    Runs in local preview mode without writing to GITHUB_OUTPUT.

.EXAMPLE
    .\scripts\detect-changed-addons.ps1 -Local
    .\scripts\detect-changed-addons.ps1 -ManualTarget "perf-biggins" -Local
#>

[CmdletBinding()]
param(
    [string]$ManualTarget = "",
    [string]$BaseRef = "",
    [switch]$Local
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$configPath = Join-Path $PSScriptRoot "addons-config.json"

if (-not (Test-Path $configPath)) {
    throw "Addons configuration file not found at: $configPath"
}

$config = Get-Content -Path $configPath -Raw -Encoding utf8 | ConvertFrom-Json
$addonsMap = if ($config.addons) { $config.addons } else { $config }
$allAddons = @($addonsMap.PSObject.Properties.Name)

$selected = @()

if (-not [string]::IsNullOrWhiteSpace($ManualTarget)) {
    Write-Host "Manual trigger requested for target: '$ManualTarget'"
    if ($ManualTarget -eq "all") {
        $selected = $allAddons
    } elseif ($allAddons -contains $ManualTarget) {
        $selected = @($ManualTarget)
    } else {
        throw "Invalid manual target '$ManualTarget'. Valid options: all, $($allAddons -join ', ')"
    }
} else {
    Push-Location $repoRoot
    try {
        if ($Local) {
            # Local preview: inspect uncommitted working tree and staged index
            $unstaged = @(git diff --name-only 2>$null)
            $staged = @(git diff --name-only --cached 2>$null)
            $untracked = @(git ls-files --others --exclude-standard 2>$null)
            $changedFiles = @($unstaged + $staged + $untracked) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
            $fileCount = if ($changedFiles) { $changedFiles.Count } else { 0 }
            Write-Host "Local preview: Evaluating working tree changes ($fileCount files)..."

            if (-not $changedFiles -or $changedFiles.Count -eq 0) {
                Write-Host "No uncommitted changes detected; evaluating latest commit HEAD~1..HEAD..."
                $changedFiles = git diff --name-only HEAD~1 HEAD 2>$null
            }
        } else {
            $diffTarget = if (-not [string]::IsNullOrWhiteSpace($BaseRef)) { $BaseRef } else { "HEAD~1" }
            Write-Host "Evaluating git changes against: $diffTarget"

            $changedFiles = git diff --name-only $diffTarget HEAD 2>$null
            if ($LASTEXITCODE -ne 0 -or -not $changedFiles) {
                Write-Host "Comparison with $diffTarget returned no files or failed; checking uncommitted/latest changes..."
                $changedFiles = git diff --name-only HEAD 2>$null
            }
        }
    } finally {
        Pop-Location
    }

    $suiteChanged = $false
    foreach ($file in $changedFiles) {
        if ($file -like "lib-biggins-suite/*") {
            $suiteChanged = $true
            break
        }
    }

    if ($suiteChanged) {
        Write-Host "Shared library 'lib-biggins-suite/' changed -> Queuing ALL addons for release."
        $selected = $allAddons
    } else {
        foreach ($addon in $allAddons) {
            $prefix = "$addon/"
            $hasChanges = $false
            foreach ($file in $changedFiles) {
                if ($file.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $hasChanges = $true
                    break
                }
            }
            if ($hasChanges) {
                $selected += $addon
            }
        }
    }
}

Write-Host "Selected addons to publish: $($selected.Count)"
foreach ($item in $selected) {
    Write-Host "  - $item"
}

$jsonMatrix = @($selected) | ConvertTo-Json -Compress

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT) -and -not $Local) {
    "matrix=$jsonMatrix" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    Write-Host "Exported matrix to GITHUB_OUTPUT: matrix=$jsonMatrix"
}

return $selected
