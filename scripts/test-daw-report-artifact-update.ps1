param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputDir = Join-Path $repoRoot "build-tracer\daw-report-artifact-update-smoke"
$assetDir = Join-Path $outputDir "dot-assets"
$reportPath = Join-Path $outputDir "prettyscope-daw-test-report.md"
$exportDir = Join-Path $outputDir "exports"
$presetPath = Join-Path $outputDir "Prettyscope artifact helper smoke.preset"
$sessionPath = Join-Path $outputDir "Prettyscope artifact helper smoke.dawsession"

New-Item -ItemType Directory -Force -Path $outputDir, $exportDir | Out-Null

$assets = @(& (Join-Path $PSScriptRoot "new-dot-image-test-assets.ps1") `
        -OutputDir $assetDir `
        -PassThru)

& (Join-Path $PSScriptRoot "new-daw-test-report.ps1") `
    -Format CLAP `
    -Daw "ArtifactUpdateSmoke" `
    -Tester "Tracer" `
    -AudioSource "test sine" `
    -DotImageAssetPaths $assets `
    -OutputPath $reportPath `
    -SkipFreshnessCheck | Out-Null

$dot1Generated = Join-Path $exportDir "dot1-generated.png"
$dot1Loaded = Join-Path $exportDir "dot1-loaded.png"
$dot2Generated = Join-Path $exportDir "dot2-generated.png"
$dot2Loaded = Join-Path $exportDir "dot2-loaded.png"
Copy-Item -LiteralPath $assets[0] -Destination $dot1Generated -Force
Copy-Item -LiteralPath $assets[1] -Destination $dot1Loaded -Force
Copy-Item -LiteralPath $assets[0] -Destination $dot2Generated -Force
Copy-Item -LiteralPath $assets[1] -Destination $dot2Loaded -Force
Set-Content -Path $presetPath -Value "artifact helper smoke preset" -Encoding UTF8
Set-Content -Path $sessionPath -Value "artifact helper smoke session" -Encoding UTF8

$update = & (Join-Path $PSScriptRoot "update-daw-test-report-artifacts.ps1") `
    -ReportPath $reportPath `
    -Dot1GeneratedPng $dot1Generated `
    -Dot1LoadedPng $dot1Loaded `
    -Dot2GeneratedPng $dot2Generated `
    -Dot2LoadedPng $dot2Loaded `
    -PresetPath $presetPath `
    -SessionPath $sessionPath `
    -PassThru

$content = Get-Content -Raw -Path $reportPath
$requiredValues = @(
    (Resolve-Path $dot1Generated).Path,
    (Resolve-Path $dot1Loaded).Path,
    (Resolve-Path $dot2Generated).Path,
    (Resolve-Path $dot2Loaded).Path,
    (Resolve-Path $presetPath).Path,
    (Resolve-Path $sessionPath).Path
)

$issues = New-Object System.Collections.Generic.List[string]
foreach ($value in $requiredValues) {
    if ($content -notmatch [regex]::Escape($value)) {
        $issues.Add("Report is missing updated artifact value: $value") | Out-Null
    }
}

$review = & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
    -ReportPath $reportPath `
    -Quiet `
    -PassThru

$artifactIssues = @($review.Issues | Where-Object {
        $_ -match "Produced artifact field is blank" -or
        $_ -match "Missing produced artifact field"
    })
if ($artifactIssues.Count -gt 0) {
    $issues.Add("Reviewer still reports produced-artifact issues: $([string]::Join('; ', $artifactIssues))") | Out-Null
}

if ($update.UpdatedFields.Count -ne 6) {
    $issues.Add("Expected 6 updated artifact fields, got $($update.UpdatedFields.Count).") | Out-Null
}

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = (Resolve-Path $reportPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed DAW report artifact update helper"
Write-Host "  Report: $reportPath"

if ($issues.Count -eq 0) {
    Write-Host "DAW report artifact update helper fills produced artifact fields."
    exit 0
}

Write-Host "DAW report artifact update helper found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
