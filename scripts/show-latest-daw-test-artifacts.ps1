param(
    [string] $BuildDir = "build-tracer",
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$readinessRoot = Join-Path $repoRoot "$BuildDir\daw-readiness"
$reportRoot = Join-Path $repoRoot "docs\test-reports"
$bundleRoot = Join-Path $repoRoot "$BuildDir\daw-test-bundle"
$buildRoot = Join-Path $repoRoot $BuildDir

function Get-LatestItem {
    param(
        [string] $Path,
        [string] $Filter,
        [switch] $Directory
    )

    if (!(Test-Path $Path)) {
        return $null
    }

    $items = if ($Directory) {
        Get-ChildItem -Path $Path -Directory -Recurse -ErrorAction SilentlyContinue
    }
    else {
        Get-ChildItem -Path $Path -File -Filter $Filter -Recurse -ErrorAction SilentlyContinue
    }

    return $items | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Get-LatestFileByName {
    param(
        [string] $Path,
        [string] $Name
    )

    if (!(Test-Path $Path)) {
        return $null
    }

    return Get-ChildItem -Path $Path -File -Filter $Name -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

$latestReadinessReport = Get-LatestFileByName `
    -Path $buildRoot `
    -Name "prettyscope-daw-test-report.md"
if (!$latestReadinessReport) {
    $latestReadinessReport = Get-LatestItem -Path $reportRoot -Filter "*daw-test-report*.md"
}

$latestManifest = Get-LatestItem -Path $buildRoot -Filter "*bundle-manifest.md"
$latestBundleZip = Get-LatestItem -Path $buildRoot -Filter "*daw-test-bundle*.zip"
$latestBundleFolder = if ($latestManifest) {
    Get-Item (Split-Path -Parent $latestManifest.FullName)
}
else {
    $null
}

function Format-PathOrMissing {
    param([System.IO.FileSystemInfo] $Item)

    if (!$Item) {
        return "(none found)"
    }

    return $Item.FullName
}

Write-Host "Latest Prettyscope DAW test artifacts"
Write-Host "  Report:        $(Format-PathOrMissing $latestReadinessReport)"
Write-Host "  Manifest:      $(Format-PathOrMissing $latestManifest)"
Write-Host "  Bundle folder: $(Format-PathOrMissing $latestBundleFolder)"
Write-Host "  Bundle zip:    $(Format-PathOrMissing $latestBundleZip)"

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = if ($latestReadinessReport) { $latestReadinessReport.FullName } else { $null }
        ManifestPath = if ($latestManifest) { $latestManifest.FullName } else { $null }
        BundleDirectory = if ($latestBundleFolder) { $latestBundleFolder.FullName } else { $null }
        BundleZipPath = if ($latestBundleZip) { $latestBundleZip.FullName } else { $null }
    }
}
