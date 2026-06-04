param(
    [ValidateSet("CLAP", "VST3")]
    [string] $Format = "CLAP",
    [string] $BuildDir = "build-tracer",
    [string] $Daw = "",
    [string] $DawVersion = "",
    [string] $Tester = "",
    [string] $AudioSource = "",
    [string[]] $DotImageAssetPaths = @(),
    [string] $OutputPath = "",
    [switch] $SkipFreshnessCheck,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$reportsDir = Join-Path $repoRoot "docs\test-reports"

Add-Type -AssemblyName System.Drawing

function Get-InstalledPluginPath {
    param([string] $PluginFormat)

    if ($PluginFormat -eq "CLAP") {
        return Join-Path $env:LOCALAPPDATA "Programs\Common\CLAP\Prettyscope.clap"
    }

    return Join-Path $env:LOCALAPPDATA "Programs\Common\VST3\Prettyscope.vst3"
}

function Format-DotImageAssetLine {
    param([string] $AssetPath)

    $resolvedPath = (Resolve-Path $AssetPath).Path
    $file = Get-Item $resolvedPath
    $image = [System.Drawing.Image]::FromFile($resolvedPath)
    try {
        return "- ``$resolvedPath`` ($($image.Width)x$($image.Height), $($file.Length) bytes)"
    }
    finally {
        $image.Dispose()
    }
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
    $dotImageAssetLines = "- None generated for this report."

    if ($DotImageAssetPaths.Count -gt 0) {
        $dotImageAssetLines = ($DotImageAssetPaths | ForEach-Object {
                Format-DotImageAssetLine $_
            }) -join "`r`n"
    }

    $visualControlLines = @"
- Signal: Input Gain, Time Scale.
- Beam: Beam Intensity, Trace Width, Glow Strength, Glow Width.
- Phosphor: Phosphor Decay, Fast Decay, Afterglow.
- Dot 1: Dot 1 Intensity, Dot 1 Size, Dot 1 Halo, Dot 1 Image Mix, Dot 1 Rotation, Dot 1 Aspect.
- Dot 2: Dot 2 Intensity, Dot 2 Size, Dot 2 Halo, Dot 2 Image Mix, Dot 2 Rotation, Dot 2 Aspect.
- Dot Overall: Overall Dot Intensity, Overall Dot Size, Overall Dot Halo, Overall Dot Image Mix.
- Screen Burn: Screen Burn Persistence, Screen Burn Fast Decay, Screen Burn Afterglow, Screen Burn Floor Fade.
"@

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
- Installed artifact path: $installedPath
- Installed artifact SHA256: $installedHash
- Audio source used: $AudioSource

## Preflight

- ``scripts\show-local-plugin-status.ps1 -RequireFresh`` passed: yes
- Build artifacts matched installed artifacts: yes
- Notes:

## Dot Image Test Assets

$dotImageAssetLines
- Load the soft-core dot and asymmetric streak assets into both Dot 1 and Dot 2.
- Use the asymmetric streak to check rotation, aspect, image mix, and clear behavior.

## Test Artifacts Produced

- Dot 1 generated PNG export:
- Dot 1 loaded PNG export:
- Dot 2 generated PNG export:
- Dot 2 loaded PNG export:
- Preset name/path used:
- DAW session/project path used:

## Visual Controls Under Test

$visualControlLines

## Test Procedure

Use these steps to fill the matching result rows below.

1. Scan/load Prettyscope in the host and instantiate it on an audio track.
2. Play a steady synth, loop, or test tone and confirm audio still reaches the
   track/master output.
3. Open the editor, confirm the trace follows the audio, and watch the snapshot
   inspector while changing input level.
4. Move at least one control in each visual group: Signal, Beam, Phosphor,
   Dot 1, Dot 2, Dot Overall, and Screen Burn.
5. For Dot Overall, change the overall intensity/size/halo/image mix controls
   and confirm both dots respond together without losing individual dot offsets.
6. For Screen Burn, check that persistence lingers, fast decay affects the
   first falloff, afterglow changes the tail, and floor fade eventually clears
   old burn-in.
7. For each dot, save a generated PNG, load the soft-core and asymmetric streak
   test images, adjust image mix/rotation/aspect, save the loaded PNG, then
   click Clear and confirm the dot returns to Generated mode.
8. Load an intentionally large image, confirm it is accepted and status labels
   show bounded dimensions.
9. Save/reload a plugin preset, then save/reopen the DAW session, and confirm
   loaded images and visual settings restore.
10. Close/reopen the editor during playback and watch for black frames,
    crashes, stuck textures, or stale controls.

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
| Dot image save exports generated and loaded PNGs |  |  |
| Large image resize behavior |  |  |
| Preset save/reload restores images |  |  |
| DAW session save/reopen restores images |  |  |
| Editor remains stable during close/reopen |  |  |

## Visual Notes

- Trace appearance:
  - Watch for dotted endpoints, reset-line artifacts, jitter, excessive smear, or black OpenGL frames.
- Screen burn feel:
  - Note whether burn fades slowly but surely, stays forever, or disappears too quickly.
- Dot image appearance:
  - Compare generated dots against loaded images; note size, halo, rotation, aspect, and mix behavior.
- Dot image save behavior:
  - Save once in Generated mode and once with a loaded override; note whether both PNG exports succeed.
- Control layout pain points:
  - Note controls that are hard to find, too sensitive, too cramped, or unclear in the DAW editor.
- Performance/frame-rate notes:
  - Note visible stalls, host UI lag, or heavy CPU/GPU behavior while the editor is open.

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
    $createdPath = (Resolve-Path $OutputPath).Path
    Write-Host "Created DAW test report: $createdPath"

    if ($PassThru) {
        Write-Output $createdPath
    }
}
finally {
    Pop-Location
}
