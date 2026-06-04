param(
    [ValidateSet("CLAP", "VST3")]
    [string] $Format = "CLAP",
    [string] $BuildDir = "build-tracer",
    [string] $Daw = "",
    [string] $DawVersion = "",
    [string] $Tester = "",
    [string] $AudioSource = "",
    [string] $OutputPath = ""
)

$ErrorActionPreference = "Stop"

$buildFormat = "All"

& (Join-Path $PSScriptRoot "build-test-install-local-plugin.ps1") `
    -Format $buildFormat `
    -BuildDir $BuildDir

$reportArgs = @{
    Format = $Format
    BuildDir = $BuildDir
    Daw = $Daw
    DawVersion = $DawVersion
    Tester = $Tester
    AudioSource = $AudioSource
}

if ($OutputPath) {
    $reportArgs.OutputPath = $OutputPath
}

& (Join-Path $PSScriptRoot "new-daw-test-report.ps1") @reportArgs
