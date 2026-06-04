param(
    [Parameter(Mandatory = $true)]
    [string] $ReportPath,
    [string] $MatrixPath = "",
    [switch] $AddMissing,
    [switch] $Preview,
    [switch] $Quiet,
    [switch] $SkipDashboard
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$MatrixPath) {
    $MatrixPath = Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md"
}

if (!(Test-Path $ReportPath)) {
    throw "Missing DAW report: $ReportPath"
}

$resolvedReportPath = (Resolve-Path $ReportPath).Path
$resolvedMatrixPath = if (Test-Path $MatrixPath) {
    (Resolve-Path $MatrixPath).Path
}
else {
    $MatrixPath
}

if (!$Quiet) {
    Write-Host "Submitting Prettyscope DAW test report"
    Write-Host "  Report: $resolvedReportPath"
    Write-Host "  Matrix: $resolvedMatrixPath"
}

& (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
    -ReportPath $resolvedReportPath `
    -RequireComplete `
    -Quiet:$Quiet
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$updateArgs = @{
    ReportPath = $resolvedReportPath
    MatrixPath = $resolvedMatrixPath
}
if ($AddMissing) {
    $updateArgs.AddMissing = $true
}
if ($Preview) {
    $updateArgs.Preview = $true
}
if ($Quiet) {
    $updateArgs.Quiet = $true
}

& (Join-Path $PSScriptRoot "update-daw-host-matrix-from-report.ps1") @updateArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($Preview) {
    if (!$Quiet) {
        Write-Host ""
        Write-Host "Preview only. Rerun without -Preview after the row looks correct."
    }
    return
}

$matrixReview = & (Join-Path $PSScriptRoot "test-daw-host-matrix.ps1") `
    -MatrixPath $resolvedMatrixPath `
    -PassThru:$Quiet
if ($Quiet) {
    if (!$matrixReview.Complete) {
        foreach ($issue in $matrixReview.Issues) {
            Write-Host "DAW host matrix issue: $issue"
        }
        exit 1
    }
}
else {
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if (!$Quiet) {
    Write-Host ""
    & (Join-Path $PSScriptRoot "show-daw-release-gates.ps1") -MatrixPath $resolvedMatrixPath
}

if (!$Quiet -and !$SkipDashboard -and $resolvedMatrixPath -eq (Resolve-Path (Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md")).Path) {
    Write-Host ""
    & (Join-Path $PSScriptRoot "show-daw-test-dashboard.ps1")
}
