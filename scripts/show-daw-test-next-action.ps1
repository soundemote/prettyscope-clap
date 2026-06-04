param(
    [string] $BuildDir = "build-tracer",
    [string] $MatrixPath = "",
    [switch] $IncludeBuildScratch,
    [switch] $OpenReport
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$MatrixPath) {
    $MatrixPath = Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md"
}
$resolvedMatrixPath = if (Test-Path $MatrixPath) {
    (Resolve-Path $MatrixPath).Path
}
else {
    $MatrixPath
}
$defaultMatrixPath = (Resolve-Path (Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md")).Path

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

function Read-MatrixRows {
    param([string] $Path)

    if (!(Test-Path $Path)) {
        return @()
    }

    return @(Get-Content -Path $Path | Where-Object {
            $_ -match '^\| [^|]+ \| [^|]+ \| [^|]+ \| [^|]+ \|'
        } | Where-Object {
            $_ -notmatch '^\| Host ' -and $_ -notmatch '^\| ---'
        } | ForEach-Object {
            $cells = $_.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
            [PSCustomObject]@{
                Host = $cells[0]
                Format = $cells[1]
                OS = $cells[2]
                Status = $cells[3]
                LatestReport = $cells[4]
                ResolvedReportPath = Resolve-ReportPath $cells[4]
            }
        })
}

Push-Location $repoRoot
try {
    $reports = @(& (Join-Path $PSScriptRoot "show-daw-test-report-index.ps1") `
            -BuildDir $BuildDir `
            -IncludeBuildScratch:([bool] $IncludeBuildScratch) `
            -Quiet `
            -PassThru)
    $matrixRows = Read-MatrixRows -Path $MatrixPath
    $submittedReportPaths = @{}
    foreach ($row in $matrixRows) {
        if ($row.ResolvedReportPath) {
            $submittedReportPaths[$row.ResolvedReportPath.ToLowerInvariant()] = $true
        }
    }

    $incompleteReports = @($reports | Where-Object { $_.Complete -eq "no" })
    if ($incompleteReports.Count -gt 0) {
        $latest = $incompleteReports | Sort-Object Modified -Descending | Select-Object -First 1
        Write-Host "Next DAW test action: fill the latest incomplete report."
        Write-Host "  Report: $($latest.Path)"
        Write-Host "  Issues: $($latest.Issues)"
        Write-Host ""
        Write-Host "Latest grouped artifacts:"
        & (Join-Path $PSScriptRoot "show-latest-daw-test-artifacts.ps1") `
            -BuildDir $BuildDir
        Write-Host ""
        Write-Host "Review command:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\review-daw-test-report.ps1 -ReportPath `"$($latest.Path)`" -RequireComplete"
        if ($OpenReport) {
            Invoke-Item -LiteralPath $latest.Path
            Write-Host "Opened report: $($latest.Path)"
        }
        return
    }

    $completeReports = @($reports | Where-Object { $_.Complete -eq "yes" })
    $unsubmittedCompleteReports = @($completeReports | Where-Object {
            !$submittedReportPaths.ContainsKey($_.Path.ToLowerInvariant())
        })
    if ($unsubmittedCompleteReports.Count -gt 0) {
        $latest = $unsubmittedCompleteReports | Sort-Object Modified -Descending | Select-Object -First 1
        Write-Host "Next DAW test action: submit the latest completed report."
        Write-Host "  Report: $($latest.Path)"
        Write-Host ""
        Write-Host "Latest grouped artifacts:"
        & (Join-Path $PSScriptRoot "show-latest-daw-test-artifacts.ps1") `
            -BuildDir $BuildDir
        Write-Host ""
        Write-Host "Preview command:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath `"$($latest.Path)`" -Preview"
        Write-Host ""
        Write-Host "Submit command:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath `"$($latest.Path)`""
        if ($OpenReport) {
            Invoke-Item -LiteralPath $latest.Path
            Write-Host "Opened report: $($latest.Path)"
        }
        return
    }

    $releaseGates = & (Join-Path $PSScriptRoot "show-daw-release-gates.ps1") `
        -MatrixPath $MatrixPath `
        -Quiet `
        -PassThru
    if ($releaseGates.Ready) {
        Write-Host "Next DAW test action: first-pass release gates are ready."
        Write-Host ""
        Write-Host "Review command:"
        $dashboardCommand = "powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-dashboard.ps1"
        if ($resolvedMatrixPath -ne $defaultMatrixPath) {
            $dashboardCommand += " -MatrixPath `"$resolvedMatrixPath`""
        }
        Write-Host "  $dashboardCommand"
        return
    }

    Write-Host "Next DAW test action: prepare a first DAW test package."
    Write-Host "  Release gates still need pass-ready DAW evidence."
    Write-Host ""
    Write-Host "Prep command:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-readiness.ps1 -Format CLAP -Daw `"Your DAW`" -Tester `"Your Name`""
}
finally {
    Pop-Location
}
