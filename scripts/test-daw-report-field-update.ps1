param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputDir = Join-Path $repoRoot "build-tracer\daw-report-field-update-smoke"
$assetDir = Join-Path $outputDir "dot-assets"
$reportPath = Join-Path $outputDir "prettyscope-daw-test-report.md"
$exportDir = Join-Path $outputDir "exports"
$presetPath = Join-Path $outputDir "Prettyscope field helper smoke.preset"
$sessionPath = Join-Path $outputDir "Prettyscope field helper smoke.dawsession"

New-Item -ItemType Directory -Force -Path $outputDir, $exportDir | Out-Null

$assets = @(& (Join-Path $PSScriptRoot "new-dot-image-test-assets.ps1") `
        -OutputDir $assetDir `
        -PassThru)

& (Join-Path $PSScriptRoot "new-daw-test-report.ps1") `
    -Format CLAP `
    -Daw "FieldUpdateSmoke" `
    -DawVersion "1.0" `
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
Set-Content -Path $presetPath -Value "field helper smoke preset" -Encoding UTF8
Set-Content -Path $sessionPath -Value "field helper smoke session" -Encoding UTF8

& (Join-Path $PSScriptRoot "update-daw-test-report-artifacts.ps1") `
    -ReportPath $reportPath `
    -Dot1GeneratedPng $dot1Generated `
    -Dot1LoadedPng $dot1Loaded `
    -Dot2GeneratedPng $dot2Generated `
    -Dot2LoadedPng $dot2Loaded `
    -PresetPath $presetPath `
    -SessionPath $sessionPath | Out-Null

$resultAreas = @(
    "Plugin scans and loads",
    "Audio passes through",
    "Scope follows input signal",
    "Snapshot inspector shows active input",
    "Visual controls respond",
    "Dot Overall multiplies Dot 1 / Dot 2",
    "Screen Burn controls decay/persistence",
    "Dot 1 image load/save/clear",
    "Dot 2 image load/save/clear",
    "Dot image save exports generated and loaded PNGs",
    "Large image resize behavior",
    "Preset save/reload restores images",
    "DAW session save/reopen restores images",
    "Editor remains stable during close/reopen"
)
foreach ($area in $resultAreas) {
    & (Join-Path $PSScriptRoot "update-daw-test-report-fields.ps1") `
        -ReportPath $reportPath `
        -ResultArea $area `
        -PassFail pass `
        -ResultNotes "Field helper smoke: $area passed." | Out-Null
}

$visualNotes = @{
    "Trace appearance" = "Field helper smoke trace appearance note."
    "Screen burn feel" = "Field helper smoke screen burn note."
    "Dot image appearance" = "Field helper smoke dot image note."
    "Dot image save behavior" = "Field helper smoke save note."
    "Control layout pain points" = "Field helper smoke control layout note."
    "Performance/frame-rate notes" = "Field helper smoke performance note."
}
foreach ($entry in $visualNotes.GetEnumerator()) {
    & (Join-Path $PSScriptRoot "update-daw-test-report-fields.ps1") `
        -ReportPath $reportPath `
        -VisualNoteField $entry.Key `
        -VisualNote $entry.Value | Out-Null
}

& (Join-Path $PSScriptRoot "update-daw-test-report-fields.ps1") `
    -ReportPath $reportPath `
    -ReadyForNextVisualPolish yes `
    -NeedsCodeFixBeforeMoreTesting no `
    -HighestPriorityFollowUp "Field helper smoke complete." | Out-Null

$review = & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
    -ReportPath $reportPath `
    -Quiet `
    -PassThru

$issues = New-Object System.Collections.Generic.List[string]
if (!$review.Complete) {
    $issues.Add("Updated report should be complete: $([string]::Join('; ', $review.Issues))") | Out-Null
}
if (!$review.Passed) {
    $issues.Add("Updated report should be pass-ready.") | Out-Null
}

$content = Get-Content -Raw -Path $reportPath
foreach ($needle in @(
        "| Scope follows input signal | pass | Field helper smoke: Scope follows input signal passed. |",
        "- Trace appearance: Field helper smoke trace appearance note.",
        "- Ready for next visual polish pass: yes",
        "- Needs code fix before more testing: no",
        "- Highest-priority follow-up: Field helper smoke complete."
    )) {
    if ($content -notmatch [regex]::Escape($needle)) {
        $issues.Add("Report is missing field helper update: $needle") | Out-Null
    }
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

Write-Host "Reviewed DAW report field update helper"
Write-Host "  Report: $reportPath"

if ($issues.Count -eq 0) {
    Write-Host "DAW report field update helper fills result rows, visual notes, and release decisions."
    exit 0
}

Write-Host "DAW report field update helper found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
