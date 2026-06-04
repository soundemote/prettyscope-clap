param(
    [string] $BuildDir = "build-tracer",
    [string] $ReportPath = "",
    [string] $OutputPath = "",
    [switch] $DocsOnlyReports,
    [switch] $IncludeSmokeReports,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

function Resolve-LatestReportPath {
    $indexArgs = @{
        BuildDir = $BuildDir
        Quiet = $true
        PassThru = $true
    }
    if (!$DocsOnlyReports) {
        $indexArgs.IncludeBuildScratch = $true
    }
    if ($IncludeSmokeReports) {
        $indexArgs.IncludeSmokeReports = $true
    }

    $reports = @(& (Join-Path $PSScriptRoot "show-daw-test-report-index.ps1") @indexArgs)
    $selected = $reports |
        Where-Object { $_.Complete -eq "no" } |
        Sort-Object Modified -Descending |
        Select-Object -First 1

    if (!$selected) {
        $selected = $reports |
            Sort-Object Modified -Descending |
            Select-Object -First 1
    }

    if (!$selected) {
        throw "No DAW test reports found."
    }

    return $selected.Path
}

if (!$ReportPath) {
    $ReportPath = Resolve-LatestReportPath
}
if (!(Test-Path $ReportPath)) {
    throw "Report file is missing: $ReportPath"
}
$resolvedReportPath = (Resolve-Path $ReportPath).Path

if (!$OutputPath) {
    $reportDir = Split-Path -Parent $resolvedReportPath
    $OutputPath = Join-Path $reportDir "prettyscope-daw-test-answer-sheet.json"
}
$outputParent = Split-Path -Parent $OutputPath
if ($outputParent) {
    New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
}

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

$visualNoteFields = @(
    "Trace appearance",
    "Screen burn feel",
    "Dot image appearance",
    "Dot image save behavior",
    "Control layout pain points",
    "Performance/frame-rate notes"
)

$sheet = [ordered]@{
    reportPath = $resolvedReportPath
    artifacts = [ordered]@{
        dot1GeneratedPng = ""
        dot1LoadedPng = ""
        dot2GeneratedPng = ""
        dot2LoadedPng = ""
        presetPath = ""
        sessionPath = ""
    }
    results = @($resultAreas | ForEach-Object {
            [ordered]@{
                area = $_
                passFail = ""
                notes = ""
            }
        })
    visualNotes = [ordered]@{}
    releaseDecision = [ordered]@{
        readyForNextVisualPolish = ""
        needsCodeFixBeforeMoreTesting = ""
        highestPriorityFollowUp = ""
    }
    issues = @(
        [ordered]@{
            severity = ""
            area = ""
            description = ""
            reproSteps = ""
        }
    )
}

foreach ($field in $visualNoteFields) {
    $sheet.visualNotes[$field] = ""
}

$json = $sheet | ConvertTo-Json -Depth 8
Set-Content -Path $OutputPath -Value $json -Encoding UTF8
$createdPath = (Resolve-Path $OutputPath).Path

Write-Host "Created DAW test answer sheet: $createdPath"
Write-Host "  Report: $resolvedReportPath"

if ($PassThru) {
    [PSCustomObject]@{
        AnswerPath = $createdPath
        ReportPath = $resolvedReportPath
    }
}
