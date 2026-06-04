param(
    [string] $BuildDir = "build-tracer",
    [string] $OutputPath = "",
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$assetRoot = Join-Path $repoRoot "$BuildDir\prettyscope-clap_assets"

function Get-ArtifactSize {
    param([System.IO.FileSystemInfo] $Artifact)

    if ($Artifact.PSIsContainer) {
        return (Get-ChildItem -Recurse -File -Path $Artifact.FullName |
            Measure-Object -Property Length -Sum).Sum
    }

    return $Artifact.Length
}

function Get-ArtifactHash {
    param([System.IO.FileSystemInfo] $Artifact)

    if (!$Artifact.PSIsContainer) {
        return (Get-FileHash -Algorithm SHA256 -Path $Artifact.FullName).Hash
    }

    $relativeHashes = Get-ChildItem -Recurse -File -Path $Artifact.FullName |
        Sort-Object FullName |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($Artifact.FullName.Length).TrimStart('\', '/')
            $fileHash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash
            "${relativePath}:${fileHash}"
        }

    $joined = [string]::Join("`n", $relativeHashes)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "")
    }
    finally {
        $sha.Dispose()
    }
}

function Format-ArtifactLine {
    param(
        [string] $Label,
        [string] $Path
    )

    if (!(Test-Path $Path)) {
        return "| $Label | missing | ``$Path`` |  |  |  |"
    }

    $artifact = Get-Item $Path
    $size = Get-ArtifactSize $artifact
    $hash = Get-ArtifactHash $artifact
    return "| $Label | present | ``$($artifact.FullName)`` | $size | $($artifact.LastWriteTime) | $hash |"
}

function Format-FileLine {
    param([string] $Path)

    $resolved = Resolve-Path (Join-Path $repoRoot $Path)
    $file = Get-Item $resolved
    $hash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash
    return "| ``$Path`` | $($file.Length) | $hash |"
}

Push-Location $repoRoot
try {
    $branch = (& git branch --show-current 2>$null)
    $commit = (& git rev-parse --short HEAD 2>$null)
    $dirty = (& git status --short 2>$null)
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if (!$OutputPath) {
        $manifestDir = Join-Path $repoRoot "$BuildDir\daw-test-bundle"
        New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null
        $OutputPath = Join-Path $manifestDir "$timestamp-prettyscope-daw-test-bundle-manifest.md"
    }
    else {
        $outputParent = Split-Path -Parent $OutputPath
        if ($outputParent) {
            New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
        }
    }

    $repoState = if ($dirty) { "dirty" } else { "clean" }
    $builtArtifacts = @(
        Format-ArtifactLine "Built CLAP" (Join-Path $assetRoot "CLAP\Prettyscope.clap")
        Format-ArtifactLine "Built VST3" (Join-Path $assetRoot "VST3\Prettyscope.vst3")
        Format-ArtifactLine "Built Standalone" (Join-Path $assetRoot "Standalone-prettyscope-clap_standalone\Prettyscope.exe")
    ) -join "`r`n"

    $installedArtifacts = @(
        Format-ArtifactLine "Installed CLAP" (Join-Path $env:LOCALAPPDATA "Programs\Common\CLAP\Prettyscope.clap")
        Format-ArtifactLine "Installed VST3" (Join-Path $env:LOCALAPPDATA "Programs\Common\VST3\Prettyscope.vst3")
    ) -join "`r`n"

    $handoffFiles = @(
        "README.md",
        "docs\DAW_TEST_QUICKSTART.md",
        "docs\DAW_TEST_CHECKLIST.md",
        "docs\DAW_TEST_REPORT_TEMPLATE.md",
        "docs\DAW_HOST_MATRIX.md",
        "docs\VISUAL_CONTROL_MANIFEST.md",
        "docs\PLUGIN_IDENTITY_AUDIT.md",
        "docs\RELEASE_READINESS_AUDIT.md",
        "docs\test-reports\README.md",
        "scripts\prepare-daw-test.ps1",
        "scripts\new-daw-test-report.ps1",
        "scripts\new-daw-test-bundle.ps1",
        "scripts\test-daw-test-bundle.ps1",
        "scripts\review-daw-test-report.ps1",
        "scripts\test-visual-control-manifest.ps1",
        "scripts\test-release-readiness-audit.ps1",
        "scripts\test-daw-host-matrix.ps1",
        "scripts\new-dot-image-test-assets.ps1",
        "scripts\show-latest-daw-test-artifacts.ps1",
        "scripts\show-daw-test-report-index.ps1",
        "scripts\show-daw-test-next-action.ps1",
        "scripts\show-daw-test-dashboard.ps1",
        "scripts\show-daw-host-matrix.ps1",
        "scripts\show-daw-release-gates.ps1",
        "scripts\update-daw-host-matrix-from-report.ps1",
        "scripts\submit-daw-test-report.ps1",
        "scripts\show-local-plugin-status.ps1"
    )
    $handoffLines = ($handoffFiles | ForEach-Object { Format-FileLine $_ }) -join "`r`n"

    $manifest = @"
# Prettyscope DAW Test Bundle Manifest

## Session

- Created: $date
- Repo: $repoRoot
- Branch: $branch
- Commit: $commit
- Worktree: $repoState
- Build directory: $BuildDir

## Built Artifacts

| Artifact | Status | Path | Size bytes | Modified | SHA256 |
| --- | --- | --- | --- | --- | --- |
$builtArtifacts

## Installed User-Local Artifacts

| Artifact | Status | Path | Size bytes | Modified | SHA256 |
| --- | --- | --- | --- | --- | --- |
$installedArtifacts

## Handoff Files

| File | Size bytes | SHA256 |
| --- | --- | --- |
$handoffLines

## Suggested Next Commands

    powershell -ExecutionPolicy Bypass -File .\scripts\prepare-daw-test.ps1 -Format CLAP -Daw "Your DAW"
    powershell -ExecutionPolicy Bypass -File .\scripts\show-latest-daw-test-artifacts.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-report-index.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-next-action.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-dashboard.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-host-matrix.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-release-gates.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-host-matrix-from-report.ps1 -ReportPath .\docs\test-reports\your-report.md
    powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md
    powershell -ExecutionPolicy Bypass -File .\scripts\test-visual-control-manifest.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\test-release-readiness-audit.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-host-matrix.ps1
    powershell -ExecutionPolicy Bypass -File .\scripts\review-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md
"@

    Set-Content -Path $OutputPath -Value $manifest -Encoding UTF8
    $createdPath = (Resolve-Path $OutputPath).Path
    Write-Host "Created DAW test bundle manifest: $createdPath"

    if ($PassThru) {
        Write-Output $createdPath
    }
}
finally {
    Pop-Location
}
