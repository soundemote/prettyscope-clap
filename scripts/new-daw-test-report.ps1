param(
    [ValidateSet("CLAP", "VST3")]
    [string] $Format = "CLAP",
    [string] $BuildDir = "build-tracer",
    [string] $Daw = "",
    [string] $DawVersion = "",
    [string] $Tester = "",
    [string] $AudioSource = "",
    [string] $OutputPath = "",
    [switch] $SkipFreshnessCheck
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$reportsDir = Join-Path $repoRoot "docs\test-reports"

function Get-InstalledPluginPath {
    param([string] $PluginFormat)

    if ($PluginFormat -eq "CLAP") {
        return Join-Path $env:LOCALAPPDATA "Programs\Common\CLAP\Prettyscope.clap"
    }

    return Join-Path $env:LOCALAPPDATA "Programs\Common\VST3\Prettyscope.vst3"
}

Push-Location $repoRoot
try {
    if (!$SkipFreshnessCheck) {
        & (Join-Path $PSScriptRoot "show-local-plugin-status.ps1") -BuildDir $BuildDir -RequireFresh
    }

    $commit = (& git rev-parse --short HEAD 2>$null)
    if (!$commit) {
        $commit = "unknown"
    }

    $installedPath = Get-InstalledPluginPath $Format
    if (!(Test-Path $installedPath)) {
        throw "Installed $Format artifact is missing: $installedPath"
    }

    $installedHash = (Get-FileHash -Algorithm SHA256 -Path $installedPath).Hash
    $date = Get-Date -Format "yyyy-MM-dd"
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription.Trim()

    if (!$OutputPath) {
        New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
        $OutputPath = Join-Path $reportsDir "$timestamp-prettyscope-$($Format.ToLower())-daw-test.md"
    }
    else {
        $outputParent = Split-Path -Parent $OutputPath
        if ($outputParent) {
            New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
        }
    }

    $report = @"
# Prettyscope CLAP DAW Test Report

Use this template with ``docs\DAW_TEST_CHECKLIST.md`` when testing a specific
DAW/build combination.

## Session

- Date: $date
- Tester: $Tester
- DAW: $Daw
- DAW version: $DawVersion
- OS: $os
- Plugin format tested: $Format
- Prettyscope commit: $commit
- Installed artifact SHA256: $installedHash
- Audio source used: $AudioSource

## Preflight

- ``scripts\show-local-plugin-status.ps1 -RequireFresh`` passed: yes
- Build artifacts matched installed artifacts: yes
- Notes:

## Results

| Area | Pass/Fail | Notes |
| --- | --- | --- |
| Plugin scans and loads |  |  |
| Audio passes through |  |  |
| Scope follows input signal |  |  |
| Snapshot inspector shows active input |  |  |
| Visual controls respond |  |  |
| Dot Overall multiplies Dot 1 / Dot 2 |  |  |
| Screen Burn controls decay/persistence |  |  |
| Dot 1 image load/save/clear |  |  |
| Dot 2 image load/save/clear |  |  |
| Large image resize behavior |  |  |
| Preset save/reload restores images |  |  |
| DAW session save/reopen restores images |  |  |
| Editor remains stable during close/reopen |  |  |

## Visual Notes

- Trace appearance:
- Screen burn feel:
- Dot image appearance:
- Control layout pain points:
- Performance/frame-rate notes:

## Issues Found

| Severity | Area | Description | Repro Steps |
| --- | --- | --- | --- |
|  |  |  |  |

## Release Decision

- Ready for next visual polish pass: yes / no
- Needs code fix before more testing: yes / no
- Highest-priority follow-up:
"@

    Set-Content -Path $OutputPath -Value $report -Encoding UTF8
    Write-Host "Created DAW test report: $OutputPath"
}
finally {
    Pop-Location
}
