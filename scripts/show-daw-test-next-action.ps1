param(
    [string] $BuildDir = "build-tracer",
    [switch] $IncludeBuildScratch,
    [switch] $OpenReport
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Get-Reports {
    param(
        [switch] $CompleteOnly,
        [switch] $IncompleteOnly
    )

    return @(& (Join-Path $PSScriptRoot "show-daw-test-report-index.ps1") `
            -BuildDir $BuildDir `
            -IncludeBuildScratch:$IncludeBuildScratch `
            -CompleteOnly:$CompleteOnly `
            -IncompleteOnly:$IncompleteOnly `
            -Quiet `
            -PassThru)
}

Push-Location $repoRoot
try {
    $incompleteReports = Get-Reports -IncompleteOnly
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

    $completeReports = Get-Reports -CompleteOnly
    if ($completeReports.Count -gt 0) {
        $latest = $completeReports | Sort-Object Modified -Descending | Select-Object -First 1
        Write-Host "Next DAW test action: review the latest completed report and decide follow-up."
        Write-Host "  Report: $($latest.Path)"
        Write-Host ""
        Write-Host "Latest grouped artifacts:"
        & (Join-Path $PSScriptRoot "show-latest-daw-test-artifacts.ps1") `
            -BuildDir $BuildDir
        Write-Host ""
        Write-Host "Index command:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-report-index.ps1 -CompleteOnly"
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
