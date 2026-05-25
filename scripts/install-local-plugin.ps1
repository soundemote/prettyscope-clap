param(
    [ValidateSet("All", "CLAP", "VST3")]
    [string] $Format = "All"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$assetRoot = Join-Path $repoRoot "build-ninja\prettyscope-clap_assets"

function Copy-PluginFile {
    param(
        [string] $Source,
        [string] $DestinationDirectory
    )

    if (!(Test-Path $Source)) {
        throw "Missing build artifact: $Source"
    }

    New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
    Copy-Item -Force -Path $Source -Destination $DestinationDirectory
    Write-Host "Installed $(Split-Path $Source -Leaf) -> $DestinationDirectory"
}

if ($Format -eq "All" -or $Format -eq "CLAP") {
    Copy-PluginFile `
        -Source (Join-Path $assetRoot "CLAP\Prettyscope.clap") `
        -DestinationDirectory (Join-Path $env:LOCALAPPDATA "Programs\Common\CLAP")
}

if ($Format -eq "All" -or $Format -eq "VST3") {
    Copy-PluginFile `
        -Source (Join-Path $assetRoot "VST3\Prettyscope.vst3") `
        -DestinationDirectory (Join-Path $env:LOCALAPPDATA "Programs\Common\VST3")
}
