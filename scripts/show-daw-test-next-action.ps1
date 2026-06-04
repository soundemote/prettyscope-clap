param(
    [string] $BuildDir = "build-tracer",
    [switch] $IncludeBuildScratch,
    [switch] $OpenReport
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Push-Location $repoRoot
try {
    $reports = @(& (Join-Path $PSScriptRoot "show-daw-test-report-index.ps1") `
            -BuildDir $BuildDir `
            -IncludeBuildScratch:([bool] $IncludeBuildScratch) `
            -Quiet `
            -PassThru)

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
    if ($completeReports.Count -gt 0) {
        $latest = $completeReports | Sort-Object Modified -Descending | Select-Object -First 1
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

    Write-Host "Next DAW test action: prepare a first DAW test package."
    Write-Host ""
    Write-Host "Prep command:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-readiness.ps1 -Format CLAP -Daw `"Your DAW`" -Tester `"Your Name`""
}
finally {
    Pop-Location
}
