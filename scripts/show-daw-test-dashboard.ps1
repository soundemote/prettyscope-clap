param(
    [string] $BuildDir = "build-tracer",
    [int] $ReportLimit = 5,
    [switch] $IncludeBuildScratch,
    [switch] $RequireFresh
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Write-Section {
    param([string] $Title)

    Write-Host ""
    Write-Host "== $Title =="
}

Push-Location $repoRoot
try {
    Write-Host "Prettyscope DAW test dashboard"
    Write-Host "Repo: $repoRoot"

    Write-Section "Local Plugin Status"
    & (Join-Path $PSScriptRoot "show-local-plugin-status.ps1") `
        -BuildDir $BuildDir `
        -RequireFresh:$RequireFresh

    Write-Section "Latest Artifacts"
    & (Join-Path $PSScriptRoot "show-latest-daw-test-artifacts.ps1") `
        -BuildDir $BuildDir

    Write-Section "Next Action"
    & (Join-Path $PSScriptRoot "show-daw-test-next-action.ps1") `
        -BuildDir $BuildDir `
        -IncludeBuildScratch:$IncludeBuildScratch

    Write-Section "Release Gates"
    & (Join-Path $PSScriptRoot "show-daw-release-gates.ps1")

    Write-Section "Report Index"
    & (Join-Path $PSScriptRoot "show-daw-test-report-index.ps1") `
        -BuildDir $BuildDir `
        -IncludeBuildScratch:$IncludeBuildScratch `
        -Limit $ReportLimit
}
finally {
    Pop-Location
}
