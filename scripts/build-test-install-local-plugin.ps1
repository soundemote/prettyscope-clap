param(
    [ValidateSet("All", "CLAP", "VST3")]
    [string] $Format = "All",
    [string] $BuildDir = "build-tracer"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$vcvars = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

if (!(Test-Path $vcvars)) {
    throw "Visual Studio vcvars64.bat not found at: $vcvars"
}

Push-Location $repoRoot
try {
    cmd.exe /d /c "call `"$vcvars`" && cmake -S . -B `"$BuildDir`" -G Ninja && cmake --build `"$BuildDir`" && ctest --test-dir `"$BuildDir`" --output-on-failure"
    & (Join-Path $PSScriptRoot "install-local-plugin.ps1") -Format $Format -BuildDir $BuildDir
}
finally {
    Pop-Location
}
