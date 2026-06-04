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
    [switch] $SkipBuildInstall,
    [switch] $SkipDotImageAssets,
    [switch] $SkipBundleManifest,
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
    & (Join-Path $PSScriptRoot "show-local-plugin-status.ps1") -BuildDir $BuildDir -RequireFresh
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

$reportPath = $null
if ($PassThru) {
    $reportPath = & (Join-Path $PSScriptRoot "new-daw-test-report.ps1") @reportArgs -PassThru
}
else {
    & (Join-Path $PSScriptRoot "new-daw-test-report.ps1") @reportArgs
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
        BundleManifestPath = $bundleManifest
    }
}
