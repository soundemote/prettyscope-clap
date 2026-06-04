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
    [switch] $SkipBuildInstall,
    [switch] $SkipDotImageAssets,
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

if ($PassThru) {
    $reportArgs.PassThru = $true
}

& (Join-Path $PSScriptRoot "new-daw-test-report.ps1") @reportArgs
