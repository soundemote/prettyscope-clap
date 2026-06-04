param(
    [ValidateSet("CLAP", "VST3")]
    [string] $Format = "CLAP",
    [string] $BuildDir = "build-tracer",
    [string] $Daw = "",
    [string] $DawVersion = "",
    [string] $Tester = "",
    [string] $AudioSource = "",
    [string] $OutputPath = "",
    [switch] $SkipBuildInstall
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

$reportArgs = @{
    Format = $Format
    BuildDir = $BuildDir
    Daw = $Daw
    DawVersion = $DawVersion
    Tester = $Tester
    AudioSource = $AudioSource
    SkipFreshnessCheck = $true
}

if ($OutputPath) {
    $reportArgs.OutputPath = $OutputPath
}

& (Join-Path $PSScriptRoot "new-daw-test-report.ps1") @reportArgs
