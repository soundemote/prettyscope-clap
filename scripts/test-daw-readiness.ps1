param(
    [string] $BuildDir = "build-tracer",
    [ValidateSet("CLAP", "VST3")]
    [string] $Format = "CLAP",
    [string] $Daw = "ReadinessSmoke",
    [string] $DawVersion = "0",
    [string] $Tester = "Tracer",
    [string] $AudioSource = "test sine",
    [string] $OutputDir = "",
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if (!$OutputDir) {
    $OutputDir = Join-Path $repoRoot "$BuildDir\daw-readiness\$timestamp"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Push-Location $repoRoot
try {
    Write-Host "Prettyscope DAW readiness check"
    Write-Host "Output: $OutputDir"
    Write-Host ""

    & (Join-Path $PSScriptRoot "show-local-plugin-status.ps1") `
        -BuildDir $BuildDir `
        -RequireFresh

    & (Join-Path $PSScriptRoot "test-dot-image-renderer-source.ps1")
    & (Join-Path $PSScriptRoot "test-dot-image-clear-source.ps1")
    & (Join-Path $PSScriptRoot "test-dot-image-load-source.ps1")
    & (Join-Path $PSScriptRoot "test-dot-image-save-source.ps1")
    & (Join-Path $PSScriptRoot "test-dot-image-state-source.ps1")
    & (Join-Path $PSScriptRoot "test-dot-overall-renderer-source.ps1")
    & (Join-Path $PSScriptRoot "test-screen-burn-renderer-source.ps1")
    & (Join-Path $PSScriptRoot "test-visual-control-manifest.ps1")
    & (Join-Path $PSScriptRoot "test-release-readiness-audit.ps1")
    & (Join-Path $PSScriptRoot "test-daw-host-matrix.ps1")
    & (Join-Path $PSScriptRoot "test-daw-report-artifact-update.ps1")
    & (Join-Path $PSScriptRoot "test-daw-report-field-update.ps1")
    & (Join-Path $PSScriptRoot "test-daw-report-classification.ps1")
    & (Join-Path $PSScriptRoot "test-daw-next-action-routing.ps1")

    $reportPath = Join-Path $OutputDir "prettyscope-daw-test-report.md"
    $manifestPath = Join-Path $OutputDir "prettyscope-daw-test-bundle-manifest.md"
    $prep = & (Join-Path $PSScriptRoot "prepare-daw-test.ps1") `
        -Format $Format `
        -BuildDir $BuildDir `
        -Daw $Daw `
        -DawVersion $DawVersion `
        -Tester $Tester `
        -AudioSource $AudioSource `
        -OutputPath $reportPath `
        -BundleManifestPath $manifestPath `
        -SkipBuildInstall `
        -SkipFreshnessCheck `
        -PassThru

    $reportContent = Get-Content -Raw -Path $prep.ReportPath
    foreach ($needle in @(
            "## Test Procedure",
            "Use these steps to fill the matching result rows below.",
            "Move at least one control in each visual group",
            "click Clear and confirm the dot returns to Generated mode",
            "Save/reload a plugin preset, then save/reopen the DAW session"
        )) {
        if ($reportContent -notmatch [regex]::Escape($needle)) {
            throw "Generated DAW report is missing test procedure text: $needle"
        }
    }

    $bundleDir = Join-Path $OutputDir "bundle"
    $bundleZip = Join-Path $OutputDir "prettyscope-daw-test-bundle.zip"
    $bundle = & (Join-Path $PSScriptRoot "new-daw-test-bundle.ps1") `
        -BuildDir $BuildDir `
        -OutputDir $bundleDir `
        -ZipPath $bundleZip `
        -PassThru

    $summaryPath = Join-Path $OutputDir "prettyscope-release-candidate-summary.md"
    $summary = & (Join-Path $PSScriptRoot "new-release-candidate-summary.ps1") `
        -BuildDir $BuildDir `
        -OutputPath $summaryPath `
        -PassThru

    & (Join-Path $PSScriptRoot "test-daw-handoff-current.ps1") `
        -BuildDir $BuildDir `
        -RequireCurrent

    & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
        -ReportPath $prep.ReportPath

    Write-Host ""
    Write-Host "Report review warnings are expected before hands-on DAW testing;"
    Write-Host "fill the generated report after testing, then run review-daw-test-report.ps1 again."

    Write-Host ""
    Write-Host "DAW readiness artifacts:"
    Write-Host "  Report: $($prep.ReportPath)"
    Write-Host "  Prep manifest: $($prep.BundleManifestPath)"
    Write-Host "  Bundle folder: $($bundle.BundleDirectory)"
    Write-Host "  Bundle zip: $($bundle.ZipPath)"
    Write-Host "  Release summary: $($summary.SummaryPath)"

    if ($PassThru) {
        [PSCustomObject]@{
            ReportPath = $prep.ReportPath
            PrepManifestPath = $prep.BundleManifestPath
            BundleDirectory = $bundle.BundleDirectory
            BundleZipPath = $bundle.ZipPath
            BundleManifestPath = $bundle.ManifestPath
            ReleaseSummaryPath = $summary.SummaryPath
        }
    }
}
finally {
    Pop-Location
}
