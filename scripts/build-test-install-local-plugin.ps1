param(
    [ValidateSet("All", "CLAP", "VST3")]
    [string] $Format = "All"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$vcvars = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"

if (!(Test-Path $vcvars)) {
    throw "Visual Studio vcvars64.bat not found at: $vcvars"
}

Push-Location $repoRoot
try {
    cmd.exe /d /c "call `"$vcvars`" && cmake --build build-ninja && build-ninja\tests\prettyscope-clap-tests.exe"
    & (Join-Path $PSScriptRoot "install-local-plugin.ps1") -Format $Format
}
finally {
    Pop-Location
}
