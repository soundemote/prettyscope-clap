param(
    [string] $OutputDir = "",
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$OutputDir) {
    $OutputDir = Join-Path $repoRoot "build-tracer\daw-next-action-routing-smoke"
}

if (Test-Path $OutputDir) {
    Remove-Item -LiteralPath $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$OutputDir = (Resolve-Path $OutputDir).Path

function Assert-Contains {
    param(
        [string] $Text,
        [string] $Needle,
        [string] $Message
    )

    if (!$Text.Contains($Needle)) {
        throw "$Message`nExpected to find: $Needle`nOutput:`n$Text"
    }
}

function Invoke-NextAction {
    param(
        [string] $BuildDir,
        [string] $MatrixPath,
        [switch] $ExplicitScratch
    )

    $arguments = @(
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        (Join-Path $PSScriptRoot "show-daw-test-next-action.ps1"),
        "-BuildDir",
        $BuildDir,
        "-MatrixPath",
        $MatrixPath,
        "-IncludeSmokeReports"
    )
    if ($ExplicitScratch) {
        $arguments += "-IncludeBuildScratch"
    }

    return (powershell @arguments 2>&1) | Out-String
}

function Copy-ReportWithFormat {
    param(
        [string] $Source,
        [string] $Destination,
        [string] $Format
    )

    $content = Get-Content -Raw -Path $Source
    $content = $content -replace '- Plugin format tested: (CLAP|VST3)', "- Plugin format tested: $Format"
    $content = $content -replace 'Installed artifact path: C:\\Smoke\\Prettyscope\.(clap|vst3)',
        "Installed artifact path: C:\Smoke\Prettyscope.$($Format.ToLowerInvariant())"
    Set-Content -Path $Destination -Value $content -Encoding UTF8
}

$classification = & (Join-Path $PSScriptRoot "test-daw-report-classification.ps1") `
    -OutputDir (Join-Path $OutputDir "classification") `
    -PassThru

$incompleteDir = Join-Path $OutputDir "incomplete"
$unsubmittedDir = Join-Path $OutputDir "unsubmitted"
$submittedNotReadyDir = Join-Path $OutputDir "submitted-not-ready"
$readyDir = Join-Path $OutputDir "ready"
foreach ($dir in @($incompleteDir, $unsubmittedDir, $submittedNotReadyDir, $readyDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$incompleteReport = Join-Path $incompleteDir "prettyscope-daw-test-report.md"
Copy-Item (Join-Path $repoRoot "docs\DAW_TEST_REPORT_TEMPLATE.md") $incompleteReport -Force
$incompleteMatrix = Join-Path $incompleteDir "DAW_HOST_MATRIX.md"
Copy-Item (Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md") $incompleteMatrix -Force
$incompleteOutput = Invoke-NextAction `
    -BuildDir ($incompleteDir.Substring($repoRoot.Path.Length).TrimStart('\', '/')) `
    -MatrixPath $incompleteMatrix
Assert-Contains $incompleteOutput "Next DAW test action: fill the latest incomplete report." `
    "Incomplete build scratch report should route to fill/review by default."
Assert-Contains $incompleteOutput "review-latest-daw-test-report.ps1 -RequireComplete" `
    "Incomplete report guidance should include the latest-report review command."
Assert-Contains $incompleteOutput "show-daw-test-next-action.ps1 -OpenReport" `
    "Incomplete report guidance should include an open-report command."

$unsubmittedReport = Join-Path $unsubmittedDir "prettyscope-daw-test-report.md"
Copy-Item $classification.PassingReport $unsubmittedReport -Force
$unsubmittedMatrix = Join-Path $unsubmittedDir "DAW_HOST_MATRIX.md"
Copy-Item (Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md") $unsubmittedMatrix -Force
$unsubmittedOutput = Invoke-NextAction `
    -BuildDir ($unsubmittedDir.Substring($repoRoot.Path.Length).TrimStart('\', '/')) `
    -MatrixPath $unsubmittedMatrix
Assert-Contains $unsubmittedOutput "Next DAW test action: submit the latest completed report." `
    "Unsubmitted complete report should route to submit."
Assert-Contains $unsubmittedOutput "submit-latest-daw-test-report.ps1 -Preview" `
    "Unsubmitted complete report should print latest-report preview command."
Assert-Contains $unsubmittedOutput "submit-latest-daw-test-report.ps1" `
    "Unsubmitted complete report should print latest-report submit command."
Assert-Contains $unsubmittedOutput "Result:" `
    "Unsubmitted complete report should print its result classification."
Assert-Contains $unsubmittedOutput "show-daw-test-next-action.ps1 -OpenReport" `
    "Unsubmitted complete report guidance should include an open-report command."

$submittedNotReadyMatrix = Join-Path $submittedNotReadyDir "DAW_HOST_MATRIX.md"
Copy-Item $classification.MatrixPath $submittedNotReadyMatrix -Force
$submittedNotReadyOutput = Invoke-NextAction `
    -BuildDir ($submittedNotReadyDir.Substring($repoRoot.Path.Length).TrimStart('\', '/')) `
    -MatrixPath $submittedNotReadyMatrix
Assert-Contains $submittedNotReadyOutput "Next DAW test action: prepare a first DAW test package." `
    "Submitted reports with incomplete gates should route to more DAW evidence."
Assert-Contains $submittedNotReadyOutput "Release gates still need pass-ready DAW evidence." `
    "Submitted reports with incomplete gates should explain why more evidence is needed."

$readyMatrix = Join-Path $readyDir "DAW_HOST_MATRIX.md"
Copy-Item (Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md") $readyMatrix -Force
$readyClapReport = Join-Path $readyDir "ready-clap-daw-test-report.md"
$readyVst3Report = Join-Path $readyDir "ready-vst3-daw-test-report.md"
Copy-ReportWithFormat -Source $classification.PassingReport -Destination $readyClapReport -Format "CLAP"
Copy-ReportWithFormat -Source $classification.PassingReport -Destination $readyVst3Report -Format "VST3"
& (Join-Path $PSScriptRoot "submit-daw-test-report.ps1") `
    -ReportPath $readyClapReport `
    -MatrixPath $readyMatrix `
    -AddMissing `
    -Quiet `
    -SkipDashboard
& (Join-Path $PSScriptRoot "submit-daw-test-report.ps1") `
    -ReportPath $readyVst3Report `
    -MatrixPath $readyMatrix `
    -AddMissing `
    -Quiet `
    -SkipDashboard
$readyOutput = Invoke-NextAction `
    -BuildDir ($readyDir.Substring($repoRoot.Path.Length).TrimStart('\', '/')) `
    -MatrixPath $readyMatrix
Assert-Contains $readyOutput "Next DAW test action: first-pass release gates are ready." `
    "Ready gates should route to dashboard review."
Assert-Contains $readyOutput "-MatrixPath" `
    "Ready scratch matrix should preserve MatrixPath in the dashboard command."

Write-Host "DAW next-action routing smoke passed."
Write-Host "  Output: $OutputDir"

if ($PassThru) {
    [PSCustomObject]@{
        OutputDir = (Resolve-Path $OutputDir).Path
        IncompleteMatrix = (Resolve-Path $incompleteMatrix).Path
        UnsubmittedMatrix = (Resolve-Path $unsubmittedMatrix).Path
        SubmittedNotReadyMatrix = (Resolve-Path $submittedNotReadyMatrix).Path
        ReadyMatrix = (Resolve-Path $readyMatrix).Path
    }
}
