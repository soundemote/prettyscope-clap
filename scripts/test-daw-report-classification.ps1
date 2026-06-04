param(
    [string] $OutputDir = "",
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$OutputDir) {
    $OutputDir = Join-Path $repoRoot "build-tracer\daw-report-classification-smoke"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function New-SmokeReport {
    param(
        [string] $Path,
        [string] $Format,
        [switch] $Fail
    )

    $scopeResult = if ($Fail) { "fail" } else { "pass" }
    $ready = if ($Fail) { "no" } else { "yes" }
    $needsFix = if ($Fail) { "yes" } else { "no" }
    $failureNote = if ($Fail) { "Smoke report failure." } else { "Smoke report." }

    $content = @"
# Prettyscope CLAP DAW Test Report

## Session

- Date: 2026-06-04
- Tester: Tracer
- DAW: SmokeHost
- DAW version: 1.0
- OS: Windows
- Plugin format tested: $Format
- Prettyscope commit: smoke
- Installed artifact path: C:\Smoke\Prettyscope.$($Format.ToLowerInvariant())
- Installed artifact SHA256: 0000000000000000000000000000000000000000000000000000000000000000
- Audio source used: sine

## Preflight

- ``scripts\show-local-plugin-status.ps1 -RequireFresh`` passed: yes
- Build artifacts matched installed artifacts: yes
- Notes: smoke complete

## Dot Image Test Assets

- ``C:\Smoke\prettyscope-dot-soft-core.png`` (256x256, 1024 bytes)
- ``C:\Smoke\prettyscope-dot-asymmetric-streak.png`` (256x128, 1024 bytes)

## Visual Controls Under Test

- Signal: Input Gain, Time Scale.
- Beam: Beam Intensity, Trace Width, Glow Strength, Glow Width.
- Phosphor: Phosphor Decay, Fast Decay, Afterglow.
- Dot 1: Dot 1 Intensity, Dot 1 Size, Dot 1 Halo, Dot 1 Image Mix, Dot 1 Rotation, Dot 1 Aspect.
- Dot 2: Dot 2 Intensity, Dot 2 Size, Dot 2 Halo, Dot 2 Image Mix, Dot 2 Rotation, Dot 2 Aspect.
- Dot Overall: Overall Dot Intensity, Overall Dot Size, Overall Dot Halo, Overall Dot Image Mix.
- Screen Burn: Screen Burn Persistence, Screen Burn Fast Decay, Screen Burn Afterglow, Screen Burn Floor Fade.

## Results

| Area | Pass/Fail | Notes |
| --- | --- | --- |
| Plugin scans and loads | pass | Smoke report. |
| Audio passes through | pass | Smoke report. |
| Scope follows input signal | $scopeResult | $failureNote |
| Snapshot inspector shows active input | pass | Smoke report. |
| Visual controls respond | pass | Smoke report. |
| Dot Overall multiplies Dot 1 / Dot 2 | pass | Smoke report. |
| Screen Burn controls decay/persistence | pass | Smoke report. |
| Dot 1 image load/save/clear | pass | Smoke report. |
| Dot 2 image load/save/clear | pass | Smoke report. |
| Dot image save exports generated and loaded PNGs | pass | Smoke report. |
| Large image resize behavior | pass | Smoke report. |
| Preset save/reload restores images | pass | Smoke report. |
| DAW session save/reopen restores images | pass | Smoke report. |
| Editor remains stable during close/reopen | pass | Smoke report. |

## Visual Notes

- Trace appearance: Smoke report.
- Screen burn feel: Smoke report.
- Dot image appearance: Smoke report.
- Dot image save behavior: Smoke report.
- Control layout pain points: Smoke report.
- Performance/frame-rate notes: Smoke report.

## Issues Found

| Severity | Area | Description | Repro Steps |
| --- | --- | --- | --- |
| none | none | Smoke report. | Smoke report. |

## Release Decision

- Ready for next visual polish pass: $ready
- Needs code fix before more testing: $needsFix
- Highest-priority follow-up: Smoke report.
"@

    Set-Content -Path $Path -Value $content -Encoding UTF8
}

function Assert-True {
    param(
        [bool] $Condition,
        [string] $Message
    )

    if (!$Condition) {
        throw $Message
    }
}

function Read-MatrixStatus {
    param(
        [string] $MatrixPath,
        [string] $HostName,
        [string] $Format
    )

    $rows = & (Join-Path $PSScriptRoot "show-daw-host-matrix.ps1") `
        -MatrixPath $MatrixPath `
        -PassThru
    $match = $rows.Rows | Where-Object {
        $_.Host -eq $HostName -and $_.Format -eq $Format -and $_.OS -eq "Windows"
    } | Select-Object -First 1
    if (!$match) {
        return ""
    }
    return $match.Status
}

$passReport = Join-Path $OutputDir "passing-daw-test-report.md"
$failReport = Join-Path $OutputDir "failing-daw-test-report.md"
$matrixPath = Join-Path $OutputDir "DAW_HOST_MATRIX.md"

New-SmokeReport -Path $passReport -Format "CLAP"
New-SmokeReport -Path $failReport -Format "VST3" -Fail
Copy-Item (Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md") $matrixPath -Force

$passReview = & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
    -ReportPath $passReport `
    -Quiet `
    -PassThru
$failReview = & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
    -ReportPath $failReport `
    -Quiet `
    -PassThru

Assert-True $passReview.Complete "Passing smoke report should be complete."
Assert-True $passReview.Passed "Passing smoke report should be pass-ready."
Assert-True $failReview.Complete "Failing smoke report should still be complete."
Assert-True (!$failReview.Passed) "Failing smoke report should not be pass-ready."
Assert-True ($failReview.ResultFailureCount -eq 1) "Failing smoke report should record one failed result."

& (Join-Path $PSScriptRoot "submit-daw-test-report.ps1") `
    -ReportPath $passReport `
    -MatrixPath $matrixPath `
    -AddMissing `
    -SkipDashboard
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& (Join-Path $PSScriptRoot "submit-daw-test-report.ps1") `
    -ReportPath $failReport `
    -MatrixPath $matrixPath `
    -AddMissing `
    -SkipDashboard
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Assert-True ((Read-MatrixStatus -MatrixPath $matrixPath -HostName "SmokeHost" -Format "CLAP") -eq "pass") `
    "Passing smoke report should update matrix as pass."
Assert-True ((Read-MatrixStatus -MatrixPath $matrixPath -HostName "SmokeHost" -Format "VST3") -eq "fix needed") `
    "Failing smoke report should update matrix as fix needed."

$forcedPassRejected = $false
try {
    & (Join-Path $PSScriptRoot "update-daw-host-matrix-from-report.ps1") `
        -ReportPath $failReport `
        -MatrixPath $matrixPath `
        -Status pass `
        -AddMissing
}
catch {
    $forcedPassRejected = $true
}
Assert-True $forcedPassRejected "Forced pass should be rejected for a non-pass-ready report."

Write-Host "DAW report classification smoke passed."
Write-Host "  Output: $OutputDir"

if ($PassThru) {
    [PSCustomObject]@{
        OutputDir = (Resolve-Path $OutputDir).Path
        PassingReport = (Resolve-Path $passReport).Path
        FailingReport = (Resolve-Path $failReport).Path
        MatrixPath = (Resolve-Path $matrixPath).Path
    }
}
