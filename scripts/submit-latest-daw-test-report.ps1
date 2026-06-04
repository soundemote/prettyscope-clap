param(
    [string] $BuildDir = "build-tracer",
    [string] $MatrixPath = "",
    [switch] $DocsOnlyReports,
    [switch] $IncludeSmokeReports,
    [switch] $IncludeSubmitted,
    [switch] $AddMissing,
    [switch] $Preview,
    [switch] $Quiet,
    [switch] $SkipDashboard,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$MatrixPath) {
    $MatrixPath = Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md"
}

function Resolve-ReportPath {
    param([string] $Path)

    if (!$Path) {
        return ""
    }
    if (Test-Path $Path) {
        return (Resolve-Path $Path).Path
    }

    $candidate = Join-Path $repoRoot $Path
    if (Test-Path $candidate) {
        return (Resolve-Path $candidate).Path
    }

    return ""
}

function Read-SubmittedReportPaths {
    param([string] $Path)

    $submitted = @{}
    if (!(Test-Path $Path)) {
        return $submitted
    }

    Get-Content -Path $Path | Where-Object {
        $_ -match '^\| [^|]+ \| [^|]+ \| [^|]+ \| [^|]+ \|'
    } | Where-Object {
        $_ -notmatch '^\| Host ' -and $_ -notmatch '^\| ---'
    } | ForEach-Object {
        $cells = $_.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        $resolvedReportPath = Resolve-ReportPath $cells[4]
        if ($resolvedReportPath) {
            $submitted[$resolvedReportPath.ToLowerInvariant()] = $true
        }
    }

    return $submitted
}

$indexArgs = @{
    BuildDir = $BuildDir
    CompleteOnly = $true
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
$submittedReportPaths = Read-SubmittedReportPaths -Path $MatrixPath
$candidateReports = if ($IncludeSubmitted) {
    $reports
}
else {
    @($reports | Where-Object { !$submittedReportPaths.ContainsKey($_.Path.ToLowerInvariant()) })
}

$selectedReport = $candidateReports |
    Sort-Object Modified -Descending |
    Select-Object -First 1

if (!$selectedReport) {
    if (!$Quiet) {
        Write-Host "No completed DAW test reports are ready to submit."
        if (!$IncludeSubmitted -and $reports.Count -gt 0) {
            Write-Host "  Completed reports found, but they are already recorded in the host matrix."
            Write-Host "  Add -IncludeSubmitted to resubmit the latest completed report."
        }
    }
    exit 1
}

if (!$Quiet) {
    Write-Host "Submitting latest completed DAW test report"
    Write-Host "  Report: $($selectedReport.Path)"
    Write-Host "  Result: $($selectedReport.Result)"
}

$submitArgs = @{
    ReportPath = $selectedReport.Path
    MatrixPath = $MatrixPath
}
if ($AddMissing) {
    $submitArgs.AddMissing = $true
}
if ($Preview) {
    $submitArgs.Preview = $true
}
if ($Quiet) {
    $submitArgs.Quiet = $true
}
if ($SkipDashboard) {
    $submitArgs.SkipDashboard = $true
}

& (Join-Path $PSScriptRoot "submit-daw-test-report.ps1") @submitArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($PassThru) {
    [PSCustomObject]@{
        SelectedReportPath = $selectedReport.Path
        SelectedReportResult = $selectedReport.Result
        MatrixPath = $MatrixPath
        Preview = [bool] $Preview
    }
}
