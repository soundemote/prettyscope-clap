param(
    [string] $BuildDir = "build-tracer",
    [switch] $SkipReport,
    [switch] $SkipSummary,
    [switch] $SkipBundleFolder,
    [switch] $ListOnly,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$artifacts = & (Join-Path $PSScriptRoot "show-latest-daw-test-artifacts.ps1") `
    -BuildDir $BuildDir `
    -Quiet `
    -PassThru

function Open-PathIfPresent {
    param(
        [string] $Path,
        [string] $Label
    )

    if (!$Path) {
        Write-Host "Cannot open ${Label}: none found"
        return
    }

    if (!(Test-Path $Path)) {
        Write-Host "Cannot open ${Label}: missing path $Path"
        return
    }

    if ($ListOnly) {
        Write-Host "Would open ${Label}: $Path"
        return
    }

    Invoke-Item -LiteralPath $Path
    Write-Host "Opened ${Label}: $Path"
}

Write-Host "Prettyscope DAW test handoff"
Write-Host "  Report:        $($artifacts.ReportPath)"
Write-Host "  Summary:       $($artifacts.SummaryPath)"
Write-Host "  Bundle folder: $($artifacts.BundleDirectory)"

if (!$SkipReport) {
    Open-PathIfPresent -Path $artifacts.ReportPath -Label "report"
}
if (!$SkipSummary) {
    Open-PathIfPresent -Path $artifacts.SummaryPath -Label "release summary"
}
if (!$SkipBundleFolder) {
    Open-PathIfPresent -Path $artifacts.BundleDirectory -Label "bundle folder"
}

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = $artifacts.ReportPath
        SummaryPath = $artifacts.SummaryPath
        BundleDirectory = $artifacts.BundleDirectory
    }
}
