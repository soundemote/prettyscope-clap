param(
    [ValidateSet("CLAP", "VST3")]
    [string] $Format = "CLAP",
    [string] $BuildDir = "build-tracer",
    [string] $Daw = "",
    [string] $DawVersion = "",
    [string] $Tester = "",
    [string] $AudioSource = "",
    [string] $DotImageAssetDir = "",
    [string] $OutputPath = "",
    [string] $BundleManifestPath = "",
    [string] $AnswerSheetPath = "",
    [switch] $SkipBuildInstall,
    [switch] $SkipFreshnessCheck,
    [switch] $SkipDotImageAssets,
    [switch] $SkipBundleManifest,
    [switch] $SkipAnswerSheet,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$buildFormat = "All"

if (!$SkipBuildInstall) {
    & (Join-Path $PSScriptRoot "build-test-install-local-plugin.ps1") `
        -Format $buildFormat `
        -BuildDir $BuildDir
}
else {
    if (!$SkipFreshnessCheck) {
        & (Join-Path $PSScriptRoot "show-local-plugin-status.ps1") -BuildDir $BuildDir -RequireFresh
    }
}

$dotImageAssetPaths = @()
if (!$SkipDotImageAssets) {
    $assetArgs = @{}
    if ($DotImageAssetDir) {
        $assetArgs.OutputDir = $DotImageAssetDir
    }
    $dotImageAssetPaths = @(& (Join-Path $PSScriptRoot "new-dot-image-test-assets.ps1") @assetArgs -PassThru)
}

$reportArgs = @{
    Format = $Format
    BuildDir = $BuildDir
    Daw = $Daw
    DawVersion = $DawVersion
    Tester = $Tester
    AudioSource = $AudioSource
    DotImageAssetPaths = $dotImageAssetPaths
    SkipFreshnessCheck = $true
}

if ($OutputPath) {
    $reportArgs.OutputPath = $OutputPath
}

$reportPath = & (Join-Path $PSScriptRoot "new-daw-test-report.ps1") @reportArgs -PassThru

$answerSheet = $null
if (!$SkipAnswerSheet -and $reportPath) {
    $answerArgs = @{
        ReportPath = $reportPath
    }
    if ($AnswerSheetPath) {
        $answerArgs.OutputPath = $AnswerSheetPath
    }

    if ($PassThru) {
        $answerSheet = & (Join-Path $PSScriptRoot "new-daw-test-answer-sheet.ps1") @answerArgs -PassThru
    }
    else {
        & (Join-Path $PSScriptRoot "new-daw-test-answer-sheet.ps1") @answerArgs
    }
}

$bundleManifest = $null
if (!$SkipBundleManifest) {
    $manifestArgs = @{
        BuildDir = $BuildDir
    }
    if ($BundleManifestPath) {
        $manifestArgs.OutputPath = $BundleManifestPath
    }

    if ($PassThru) {
        $bundleManifest = & (Join-Path $PSScriptRoot "new-daw-test-bundle-manifest.ps1") @manifestArgs -PassThru
    }
    else {
        & (Join-Path $PSScriptRoot "new-daw-test-bundle-manifest.ps1") @manifestArgs
    }
}

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = $reportPath
        AnswerSheetPath = if ($answerSheet) { $answerSheet.AnswerPath } else { $null }
        BundleManifestPath = $bundleManifest
    }
}
