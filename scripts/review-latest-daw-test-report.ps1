param(
    [string] $BuildDir = "build-tracer",
    [switch] $DocsOnlyReports,
    [switch] $IncludeSmokeReports,
    [switch] $OpenReport,
    [switch] $RequireComplete,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

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
$selectedReport = $reports |
    Where-Object { $_.Complete -eq "no" } |
    Sort-Object Modified -Descending |
    Select-Object -First 1
$selectionReason = "latest incomplete report"

if (!$selectedReport) {
    $selectedReport = $reports |
        Sort-Object Modified -Descending |
        Select-Object -First 1
    $selectionReason = "latest report"
}

if (!$selectedReport) {
    Write-Host "No DAW test reports found."
    if (!$DocsOnlyReports) {
        Write-Host "  Searched: docs\test-reports and $BuildDir"
    }
    else {
        Write-Host "  Searched: docs\test-reports"
    }
    exit 1
}

Write-Host "Reviewing $selectionReason`: $($selectedReport.Path)"

$review = & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
    -ReportPath $selectedReport.Path `
    -Quiet `
    -PassThru

if ($review.Complete) {
    Write-Host "Report looks complete."
    if ($review.Passed) {
        Write-Host "Report result: pass."
    }
    else {
        Write-Host "Report result: not pass."
        if ($review.ResultFailureCount -gt 0) {
            Write-Host "  Failed result areas: $([string]::Join(', ', $review.ResultFailures))"
        }
        if (!$review.ReadyForNextVisualPolish) {
            Write-Host "  Ready for next visual polish pass is not yes."
        }
        if ($review.NeedsCodeFix) {
            Write-Host "  Needs code fix before more testing is yes."
        }
    }
}
else {
    Write-Host "Report review found $($review.IssueCount) issue(s):"
    foreach ($issue in $review.Issues) {
        Write-Host "  - $issue"
    }
}

if ($OpenReport) {
    Invoke-Item -LiteralPath $selectedReport.Path
    Write-Host "Opened report: $($selectedReport.Path)"
}

if ($PassThru) {
    [PSCustomObject]@{
        SelectedReportPath = $selectedReport.Path
        SelectedReportResult = $selectedReport.Result
        SelectedReportComplete = $selectedReport.Complete
        Review = $review
    }
}

if ($RequireComplete -and !$review.Complete) {
    exit 1
}
