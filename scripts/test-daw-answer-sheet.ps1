param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outputDir = Join-Path $repoRoot "build-tracer\daw-answer-sheet-smoke"
$assetDir = Join-Path $outputDir "dot-assets"
$exportDir = Join-Path $outputDir "exports"
$reportPath = Join-Path $outputDir "prettyscope-daw-test-report.md"
$answerPath = Join-Path $outputDir "prettyscope-daw-test-answer-sheet.json"
$presetPath = Join-Path $outputDir "Prettyscope answer sheet smoke.preset"
$sessionPath = Join-Path $outputDir "Prettyscope answer sheet smoke.dawsession"

New-Item -ItemType Directory -Force -Path $outputDir, $exportDir | Out-Null

$assets = @(& (Join-Path $PSScriptRoot "new-dot-image-test-assets.ps1") `
        -OutputDir $assetDir `
        -PassThru)

& (Join-Path $PSScriptRoot "new-daw-test-report.ps1") `
    -Format CLAP `
    -Daw "AnswerSheetSmoke" `
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
Set-Content -Path $presetPath -Value "answer sheet smoke preset" -Encoding UTF8
Set-Content -Path $sessionPath -Value "answer sheet smoke session" -Encoding UTF8

$template = & (Join-Path $PSScriptRoot "new-daw-test-answer-sheet.ps1") `
    -ReportPath $reportPath `
    -OutputPath $answerPath `
    -PassThru

$answers = Get-Content -Raw -Path $template.AnswerPath | ConvertFrom-Json
$answers.artifacts.dot1GeneratedPng = $dot1Generated
$answers.artifacts.dot1LoadedPng = $dot1Loaded
$answers.artifacts.dot2GeneratedPng = $dot2Generated
$answers.artifacts.dot2LoadedPng = $dot2Loaded
$answers.artifacts.presetPath = $presetPath
$answers.artifacts.sessionPath = $sessionPath

foreach ($result in $answers.results) {
    $result.passFail = "pass"
    $result.notes = "Answer sheet smoke: $($result.area) passed."
}

$answers.visualNotes.'Trace appearance' = "Answer sheet smoke trace appearance note."
$answers.visualNotes.'Screen burn feel' = "Answer sheet smoke screen burn note."
$answers.visualNotes.'Dot image appearance' = "Answer sheet smoke dot image note."
$answers.visualNotes.'Dot image save behavior' = "Answer sheet smoke save behavior note."
$answers.visualNotes.'Control layout pain points' = "Answer sheet smoke control layout note."
$answers.visualNotes.'Performance/frame-rate notes' = "Answer sheet smoke performance note."
$answers.releaseDecision.readyForNextVisualPolish = "yes"
$answers.releaseDecision.needsCodeFixBeforeMoreTesting = "no"
$answers.releaseDecision.highestPriorityFollowUp = "Answer sheet smoke complete."

$answers | ConvertTo-Json -Depth 8 | Set-Content -Path $template.AnswerPath -Encoding UTF8

$applyResult = & (Join-Path $PSScriptRoot "apply-daw-test-answer-sheet.ps1") `
    -AnswerPath $template.AnswerPath `
    -RequireComplete `
    -PassThru

$issues = New-Object System.Collections.Generic.List[string]
if (!$applyResult.Review.Complete) {
    $issues.Add("Answer sheet application should complete the report.") | Out-Null
}
if (!$applyResult.Review.Passed) {
    $issues.Add("Answer sheet application should produce a pass-ready report.") | Out-Null
}
if ($applyResult.UpdatedFields.Count -lt 29) {
    $issues.Add("Answer sheet application updated too few fields: $($applyResult.UpdatedFields.Count)") | Out-Null
}

$content = Get-Content -Raw -Path $reportPath
foreach ($needle in @(
        "| Scope follows input signal | pass | Answer sheet smoke: Scope follows input signal passed. |",
        "- Trace appearance: Answer sheet smoke trace appearance note.",
        "- Ready for next visual polish pass: yes",
        "- Needs code fix before more testing: no",
        "- Highest-priority follow-up: Answer sheet smoke complete."
    )) {
    if ($content -notmatch [regex]::Escape($needle)) {
        $issues.Add("Report is missing answer sheet update: $needle") | Out-Null
    }
}

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = (Resolve-Path $reportPath).Path
        AnswerPath = (Resolve-Path $answerPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed DAW answer sheet helper"
Write-Host "  Report: $reportPath"
Write-Host "  Answer sheet: $answerPath"

if ($issues.Count -eq 0) {
    Write-Host "DAW answer sheet helper creates and applies a pass-ready report answer file."
    exit 0
}

Write-Host "DAW answer sheet helper found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
