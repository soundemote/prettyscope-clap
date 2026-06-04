param(
    [string] $BuildDir = "build-tracer",
    [switch] $OpenReport,
    [switch] $OpenSummary,
    [switch] $OpenBundleFolder,
    [switch] $OpenBundleZipFolder,
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

$latestManifest = $null
$latestBundleZip = $null
$latestBundleFolder = $null
$latestReleaseSummary = $null

if ($latestReadinessReport) {
    $reportDirectory = Split-Path -Parent $latestReadinessReport.FullName
    $siblingManifest = Join-Path $reportDirectory "prettyscope-daw-test-bundle-manifest.md"
    $siblingBundleZip = Join-Path $reportDirectory "prettyscope-daw-test-bundle.zip"
    $siblingBundleFolder = Join-Path $reportDirectory "bundle"
    $siblingReleaseSummary = Join-Path $reportDirectory "prettyscope-release-candidate-summary.md"

    if (Test-Path $siblingManifest) {
        $latestManifest = Get-Item $siblingManifest
    }
    if (Test-Path $siblingBundleZip) {
        $latestBundleZip = Get-Item $siblingBundleZip
    }
    if (Test-Path $siblingBundleFolder) {
        $latestBundleFolder = Get-Item $siblingBundleFolder
    }
    if (Test-Path $siblingReleaseSummary) {
        $latestReleaseSummary = Get-Item $siblingReleaseSummary
    }
}

if (!$latestManifest) {
    $latestManifest = Get-LatestItem -Path $buildRoot -Filter "*bundle-manifest.md"
}
if (!$latestReleaseSummary) {
    $latestReleaseSummary = Get-LatestItem -Path $buildRoot -Filter "prettyscope-release-candidate-summary.md"
}
if (!$latestBundleZip) {
    $latestBundleZip = Get-LatestItem -Path $buildRoot -Filter "*daw-test-bundle*.zip"
}
if (!$latestBundleFolder -and $latestManifest) {
    $candidateFolder = Get-Item (Split-Path -Parent $latestManifest.FullName)
    if ($candidateFolder.Name -eq "bundle") {
        $latestBundleFolder = $candidateFolder
    }
}

function Format-PathOrMissing {
    param([System.IO.FileSystemInfo] $Item)

    if (!$Item) {
        return "(none found)"
    }

    return $Item.FullName
}

function Open-ItemIfPresent {
    param(
        [System.IO.FileSystemInfo] $Item,
        [string] $Label
    )

    if (!$Item) {
        Write-Host "Cannot open ${Label}: none found"
        return
    }

    Invoke-Item -LiteralPath $Item.FullName
    Write-Host "Opened ${Label}: $($Item.FullName)"
}

function Open-ParentIfPresent {
    param(
        [System.IO.FileSystemInfo] $Item,
        [string] $Label
    )

    if (!$Item) {
        Write-Host "Cannot open ${Label}: none found"
        return
    }

    $parent = Split-Path -Parent $Item.FullName
    Invoke-Item -LiteralPath $parent
    Write-Host "Opened ${Label}: $parent"
}

Write-Host "Latest Prettyscope DAW test artifacts"
Write-Host "  Report:        $(Format-PathOrMissing $latestReadinessReport)"
Write-Host "  Summary:       $(Format-PathOrMissing $latestReleaseSummary)"
Write-Host "  Manifest:      $(Format-PathOrMissing $latestManifest)"
Write-Host "  Bundle folder: $(Format-PathOrMissing $latestBundleFolder)"
Write-Host "  Bundle zip:    $(Format-PathOrMissing $latestBundleZip)"

if ($OpenReport) {
    Open-ItemIfPresent -Item $latestReadinessReport -Label "report"
}
if ($OpenSummary) {
    Open-ItemIfPresent -Item $latestReleaseSummary -Label "release summary"
}
if ($OpenBundleFolder) {
    Open-ItemIfPresent -Item $latestBundleFolder -Label "bundle folder"
}
if ($OpenBundleZipFolder) {
    Open-ParentIfPresent -Item $latestBundleZip -Label "bundle zip folder"
}

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = if ($latestReadinessReport) { $latestReadinessReport.FullName } else { $null }
        SummaryPath = if ($latestReleaseSummary) { $latestReleaseSummary.FullName } else { $null }
        ManifestPath = if ($latestManifest) { $latestManifest.FullName } else { $null }
        BundleDirectory = if ($latestBundleFolder) { $latestBundleFolder.FullName } else { $null }
        BundleZipPath = if ($latestBundleZip) { $latestBundleZip.FullName } else { $null }
    }
}
