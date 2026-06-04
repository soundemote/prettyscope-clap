param(
    [string] $BuildDir = "build-tracer",
    [string] $MatrixPath = "",
    [string] $OutputPath = "",
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$MatrixPath) {
    $MatrixPath = Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md"
}
if (!$OutputPath) {
    $summaryDir = Join-Path $repoRoot "$BuildDir\release-candidate"
    New-Item -ItemType Directory -Force -Path $summaryDir | Out-Null
    $OutputPath = Join-Path $summaryDir "prettyscope-release-candidate-summary.md"
}
else {
    $parent = Split-Path -Parent $OutputPath
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
}

function Capture-Output {
    param([scriptblock] $Block)

    return (& $Block *>&1 | Out-String -Width 4096).TrimEnd()
}

function Format-Check {
    param(
        [string] $Name,
        [bool] $Pass,
        [string] $Details
    )

    $status = if ($Pass) { "pass" } else { "fail" }
    return "| $Name | $status | $Details |"
}

Push-Location $repoRoot
try {
    $branch = (& git branch --show-current 2>$null)
    $commit = (& git rev-parse --short HEAD 2>$null)
    $dirty = (& git status --short 2>$null)
    $worktree = if ($dirty) { "dirty" } else { "clean" }
    $created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $localStatus = Capture-Output {
        & (Join-Path $PSScriptRoot "show-local-plugin-status.ps1") -BuildDir $BuildDir
    }
    $nextAction = Capture-Output {
        & (Join-Path $PSScriptRoot "show-daw-test-next-action.ps1") `
            -BuildDir $BuildDir `
            -MatrixPath $MatrixPath
    }
    $latestArtifacts = Capture-Output {
        & (Join-Path $PSScriptRoot "show-latest-daw-test-artifacts.ps1") -BuildDir $BuildDir
    }

    $visualManifest = & (Join-Path $PSScriptRoot "test-visual-control-manifest.ps1") -PassThru
    $releaseAudit = & (Join-Path $PSScriptRoot "test-release-readiness-audit.ps1") -PassThru
    $hostMatrix = & (Join-Path $PSScriptRoot "test-daw-host-matrix.ps1") `
        -MatrixPath $MatrixPath `
        -PassThru
    $releaseGates = & (Join-Path $PSScriptRoot "show-daw-release-gates.ps1") `
        -MatrixPath $MatrixPath `
        -Quiet `
        -PassThru

    $checkRows = @(
        Format-Check "Visual control manifest" $visualManifest.Complete "$($visualManifest.DescriptorCount) descriptor row(s)"
        Format-Check "Release readiness audit" $releaseAudit.Complete "$($releaseAudit.IssueCount) issue(s)"
        Format-Check "DAW host matrix" $hostMatrix.Complete "$($hostMatrix.RowCount) row(s), $($hostMatrix.IssueCount) issue(s)"
        Format-Check "First-pass release gates" $releaseGates.Ready "pass-ready reports: $($releaseGates.PassReadyReportCount)"
    ) -join "`r`n"

    $gateRows = ($releaseGates.Gates | ForEach-Object {
            "| $($_.Gate) | $($_.Pass) | $($_.Evidence) |"
        }) -join "`r`n"

    $summary = @"
# Prettyscope Release Candidate Summary

## Session

- Created: $created
- Repo: $repoRoot
- Branch: $branch
- Commit: $commit
- Worktree: $worktree
- Build directory: $BuildDir
- Matrix: $((Resolve-Path $MatrixPath).Path)

## Machine Checks

| Check | Status | Details |
| --- | --- | --- |
$checkRows

## First-Pass Release Gates

Ready: $(if ($releaseGates.Ready) { "yes" } else { "no" })

| Gate | Pass | Evidence |
| --- | --- | --- |
$gateRows

## Next Action

~~~text
$nextAction
~~~

## Latest DAW Test Artifacts

~~~text
$latestArtifacts
~~~

## Local Plugin Status

~~~text
$localStatus
~~~

## Release Surface

The first testable surface includes Dot 1 and Dot 2 controls, image override
load/save/clear workflows, generated-vs-loaded dot PNG export, Dot Overall
multipliers, Screen Burn controls, pass-ready DAW report classification, and
release gates backed by linked report evidence.

Hands-on DAW testing is still required before broader release: at least one
pass-ready CLAP host report and one pass-ready VST3 host report must be recorded
in `docs\DAW_HOST_MATRIX.md`.
"@

    Set-Content -Path $OutputPath -Value $summary -Encoding UTF8
    $createdPath = (Resolve-Path $OutputPath).Path
    Write-Host "Created Prettyscope release candidate summary: $createdPath"

    if ($PassThru) {
        [PSCustomObject]@{
            SummaryPath = $createdPath
            Ready = $releaseGates.Ready
            PassReadyReportCount = $releaseGates.PassReadyReportCount
            Commit = $commit
            Worktree = $worktree
        }
    }
}
finally {
    Pop-Location
}
