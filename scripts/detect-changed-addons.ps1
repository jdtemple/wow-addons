<#
.SYNOPSIS
    Detects which Biggins addons have new versions that need to be published.

.DESCRIPTION
    Compares the current TOC version of each addon against published Git release
    tags on remote origin (refs/tags/<addon>-<version>). Any addon with an
    unreleased version tag is queued for publishing.
    If the shared library (lib-biggins-suite/) was version-bumped, all addons
    are selected for publishing.
    Supports manual target selection via workflow_dispatch.

.PARAMETER ManualTarget
    Explicit target from workflow_dispatch (e.g. "all", "perf-biggins").

.PARAMETER BaseRef
    Optional git reference or commit SHA for fallback git diff evaluation.

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
$suiteTag = ""
$suiteChanged = $false

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
        # 1. Query remote Git release tags from origin
        Write-Host "Querying published release tags from remote origin..."
        $remoteTagsRaw = @(git ls-remote --tags origin 2>$null)
        $remoteTags = @{}
        foreach ($line in $remoteTagsRaw) {
            if ($line -match 'refs/tags/([^\^]+)(\^\{\})?$') {
                $tagName = $matches[1].Trim()
                $remoteTags[$tagName] = $true
            }
        }

        # Fallback to local tags if remote was unreachable (e.g. offline testing)
        if ($remoteTags.Count -eq 0) {
            Write-Host "Remote tags could not be retrieved; checking local tags..."
            $localTags = @(git tag -l)
            foreach ($t in $localTags) {
                $remoteTags[$t.Trim()] = $true
            }
        }
        Write-Host "Discovered $($remoteTags.Count) release tags on remote."

        # 2. Check if shared suite library (lib-biggins-suite) has an unreleased version
        $suiteToc = Join-Path $repoRoot "lib-biggins-suite\LibBigginsSuite.toc"
        if (Test-Path $suiteToc) {
            $tocContent = Get-Content -Path $suiteToc -Raw -Encoding utf8
            if ($tocContent -match '(?m)^##\s*Version:\s*([^\r\n]+)') {
                $suiteVer = $matches[1].Trim()
                $expectedSuiteTag = "lib-biggins-suite-$suiteVer"
                if (-not $remoteTags.ContainsKey($expectedSuiteTag)) {
                    Write-Host "Shared suite library '$expectedSuiteTag' is untagged on remote -> Queuing ALL addons for release."
                    $suiteChanged = $true
                    $suiteTag = $expectedSuiteTag
                    $selected = $allAddons
                } else {
                    Write-Host "Shared suite library '$expectedSuiteTag' is already published."
                }
            }
        }

        # 3. Check each addon's TOC version against remote tags
        if (-not $suiteChanged) {
            foreach ($addon in $allAddons) {
                $addonDir = Join-Path $repoRoot $addon
                $tocFile = Get-ChildItem -Path $addonDir -Filter "*.toc" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $tocFile) {
                    Write-Warning "No TOC file found for addon '$addon' in $addonDir"
                    continue
                }

                $tocContent = Get-Content -Path $tocFile.FullName -Raw -Encoding utf8
                if ($tocContent -match '(?m)^##\s*Version:\s*([^\r\n]+)') {
                    $ver = $matches[1].Trim()
                    $expectedTag = "$addon-$ver"

                    if (-not $remoteTags.ContainsKey($expectedTag)) {
                        Write-Host "Addon '$addon' v$ver (tag '$expectedTag') is NOT on remote -> Queued for publish."
                        $selected += $addon
                    } else {
                        Write-Host "Addon '$addon' v$ver (tag '$expectedTag') is already published."
                    }
                } else {
                    Write-Warning "Could not determine version from $($tocFile.Name) for addon '$addon'"
                }
            }
        }

        # 4. Working tree / git diff sanity check (warn if files changed without version bump)
        if ($Local) {
            $unstaged = @(git diff --name-only 2>$null)
            $staged = @(git diff --name-only --cached 2>$null)
            $untracked = @(git ls-files --others --exclude-standard 2>$null)
            $changedFiles = @($unstaged + $staged + $untracked) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

            foreach ($addon in $allAddons) {
                $prefix = "$addon/"
                $hasFileChanges = $false
                foreach ($f in $changedFiles) {
                    if ($f.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $hasFileChanges = $true
                        break
                    }
                }
                if ($hasFileChanges -and -not ($selected -contains $addon)) {
                    Write-Warning "Addon '$addon' has modified files in git, but its current TOC version tag is already on remote. Remember to bump the version in its TOC file to trigger release!"
                }
            }
        }
    } finally {
        Pop-Location
    }
}

Write-Host "Selected addons to publish: $($selected.Count)"
foreach ($item in $selected) {
    Write-Host "  - $item"
}

# Resolve suite tag if target is all and not already set
if (-not $suiteTag -and $ManualTarget -eq "all") {
    $suiteToc = Join-Path $repoRoot "lib-biggins-suite\LibBigginsSuite.toc"
    if (Test-Path $suiteToc) {
        $tocContent = Get-Content -Path $suiteToc -Raw -Encoding utf8
        if ($tocContent -match '(?m)^##\s*Version:\s*([^\r\n]+)') {
            $suiteVer = $matches[1].Trim()
            $suiteTag = "lib-biggins-suite-$suiteVer"
            Write-Host "Detected LibBigginsSuite tag target: $suiteTag"
        }
    }
}

$jsonMatrix = if ($selected.Count -gt 0) {
    ConvertTo-Json -InputObject @($selected) -Compress
} else {
    "[]"
}

if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT) -and -not $Local) {
    "matrix=$jsonMatrix" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "suite_tag=$suiteTag" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    Write-Host "Exported matrix to GITHUB_OUTPUT: matrix=$jsonMatrix"
    if ($suiteTag) {
        Write-Host "Exported suite_tag to GITHUB_OUTPUT: suite_tag=$suiteTag"
    }
}

return $selected
