param(
    [string] $BuildDir = "build-tracer",
    [switch] $Quiet,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function New-CoverageRow {
    param(
        [string] $Requirement,
        [bool] $LocalEvidence,
        [bool] $NeedsDawEvidence,
        [string] $Evidence
    )

    [PSCustomObject]@{
        Requirement = $Requirement
        LocalEvidence = if ($LocalEvidence) { "yes" } else { "no" }
        NeedsDawEvidence = if ($NeedsDawEvidence) { "yes" } else { "no" }
        Evidence = $Evidence
    }
}

function Invoke-CoverageCheck {
    param(
        [string] $Requirement,
        [scriptblock] $Check,
        [bool] $NeedsDawEvidence,
        [string] $Evidence
    )

    try {
        $null = & $Check *>&1
        return New-CoverageRow $Requirement $true $NeedsDawEvidence $Evidence
    }
    catch {
        return New-CoverageRow $Requirement $false $NeedsDawEvidence $_.Exception.Message
    }
}

Push-Location $repoRoot
try {
    $coverage = New-Object System.Collections.Generic.List[object]

    $coverage.Add((Invoke-CoverageCheck `
                "Implementation plan exists for the requested release path" `
                { if (!(Test-Path (Join-Path $repoRoot "docs\RELEASE_READINESS_AUDIT.md"))) { throw "Missing release readiness audit." } } `
                $false `
                "docs\RELEASE_READINESS_AUDIT.md")) | Out-Null

    $coverage.Add((Invoke-CoverageCheck `
                "Dot 1 / Dot 2 / Dot Overall / Screen Burn descriptors are registered" `
                { & (Join-Path $PSScriptRoot "test-visual-control-manifest.ps1") } `
                $true `
                "scripts\test-visual-control-manifest.ps1")) | Out-Null

    $coverage.Add((Invoke-CoverageCheck `
                "Dot image render/load/save/clear/state workflow is locally covered" `
                {
                    & (Join-Path $PSScriptRoot "test-dot-image-renderer-source.ps1")
                    & (Join-Path $PSScriptRoot "test-dot-image-clear-source.ps1")
                    & (Join-Path $PSScriptRoot "test-dot-image-load-source.ps1")
                    & (Join-Path $PSScriptRoot "test-dot-image-save-source.ps1")
                    & (Join-Path $PSScriptRoot "test-dot-image-state-source.ps1")
                } `
                $true `
                "dot-image renderer/clear/load/save/state source verifiers")) | Out-Null

    $coverage.Add((Invoke-CoverageCheck `
                "Overall dot multipliers are locally covered" `
                { & (Join-Path $PSScriptRoot "test-dot-overall-renderer-source.ps1") } `
                $true `
                "scripts\test-dot-overall-renderer-source.ps1")) | Out-Null

    $coverage.Add((Invoke-CoverageCheck `
                "Screen burn controls are locally covered" `
                { & (Join-Path $PSScriptRoot "test-screen-burn-renderer-source.ps1") } `
                $true `
                "scripts\test-screen-burn-renderer-source.ps1")) | Out-Null

    $coverage.Add((Invoke-CoverageCheck `
                "DAW report tooling can complete pass-ready and fix-needed evidence" `
                {
                    & (Join-Path $PSScriptRoot "test-daw-report-artifact-update.ps1")
                    & (Join-Path $PSScriptRoot "test-daw-report-field-update.ps1")
                    & (Join-Path $PSScriptRoot "test-daw-answer-sheet.ps1")
                    & (Join-Path $PSScriptRoot "test-daw-report-classification.ps1")
                } `
                $false `
                "artifact updater, field updater, and classification smokes")) | Out-Null

    $releaseGateOutput = & (Join-Path $PSScriptRoot "show-daw-release-gates.ps1") -Quiet -PassThru *>&1
    $releaseGates = @($releaseGateOutput | Where-Object {
            $_ -isnot [string] -and $_.PSObject.Properties.Name -contains "Ready"
        } | Select-Object -Last 1)[0]
    if ($null -eq $releaseGates) {
        throw "Release gate summary did not return structured output."
    }

    $coverage.Add((Invoke-CoverageCheck `
                "Current DAW handoff package matches the repo commit" `
                { & (Join-Path $PSScriptRoot "test-daw-handoff-current.ps1") -BuildDir $BuildDir -RequireCurrent } `
                $true `
                "scripts\test-daw-handoff-current.ps1 -RequireCurrent")) | Out-Null

    $coverage.Add((New-CoverageRow `
                "First-pass DAW release gates have linked pass-ready reports" `
                $releaseGates.Ready `
                (!$releaseGates.Ready) `
                "scripts\show-daw-release-gates.ps1")) | Out-Null

    $localComplete = (@($coverage | Where-Object { $_.LocalEvidence -ne "yes" -and $_.Requirement -ne "First-pass DAW release gates have linked pass-ready reports" }).Count -eq 0)
    $dawReady = [bool] $releaseGates.Ready
    $complete = $localComplete -and $dawReady

    if (!$Quiet) {
        Write-Host "Prettyscope release objective coverage"
        Write-Host "  Local implementation coverage: $(if ($localComplete) { "yes" } else { "no" })"
        Write-Host "  DAW evidence complete:         $(if ($dawReady) { "yes" } else { "no" })"
        Write-Host "  Release objective complete:    $(if ($complete) { "yes" } else { "no" })"
        Write-Host ""
        $coverage | Format-Table -AutoSize Requirement, LocalEvidence, NeedsDawEvidence, Evidence | Out-Host
    }

    if ($PassThru) {
        [PSCustomObject]@{
            LocalImplementationCoverage = $localComplete
            DawEvidenceComplete = $dawReady
            ReleaseObjectiveComplete = $complete
            Coverage = $coverage
            ReleaseGates = $releaseGates
        }
    }
}
finally {
    Pop-Location
}
