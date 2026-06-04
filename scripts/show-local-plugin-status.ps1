param(
    [string] $BuildDir = "build-tracer"
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

function Write-ArtifactStatus {
    param(
        [string] $Label,
        [string] $Path
    )

    if (!(Test-Path $Path)) {
        Write-Host "${Label}: missing"
        Write-Host "  $Path"
        return
    }

    $artifact = Get-Item $Path
    $size = Get-ArtifactSize $artifact
    Write-Host "${Label}: present"
    Write-Host "  Path: $($artifact.FullName)"
    Write-Host "  Size: $size bytes"
    Write-Host "  Modified: $($artifact.LastWriteTime)"
}

function Get-ArtifactInfo {
    param([string] $Path)

    if (!(Test-Path $Path)) {
        return $null
    }

    $artifact = Get-Item $Path
    return [PSCustomObject]@{
        Path = $artifact.FullName
        Size = Get-ArtifactSize $artifact
        LastWriteTime = $artifact.LastWriteTime
    }
}

function Write-InstallComparison {
    param(
        [string] $Label,
        [string] $BuiltPath,
        [string] $InstalledPath
    )

    $built = Get-ArtifactInfo $BuiltPath
    $installed = Get-ArtifactInfo $InstalledPath

    if ($null -eq $built -and $null -eq $installed) {
        Write-Host "${Label}: missing build and install"
        return
    }

    if ($null -eq $built) {
        Write-Host "${Label}: missing build artifact"
        return
    }

    if ($null -eq $installed) {
        Write-Host "${Label}: not installed"
        return
    }

    $timeDelta = [Math]::Abs(($built.LastWriteTime - $installed.LastWriteTime).TotalSeconds)
    if ($built.Size -eq $installed.Size -and $timeDelta -le 2.0) {
        Write-Host "${Label}: installed copy matches build artifact"
    }
    else {
        Write-Host "${Label}: installed copy may be stale"
        Write-Host "  Built:     $($built.Size) bytes, modified $($built.LastWriteTime)"
        Write-Host "  Installed: $($installed.Size) bytes, modified $($installed.LastWriteTime)"
    }
}

Push-Location $repoRoot
try {
    $branch = (& git branch --show-current 2>$null)
    $commit = (& git rev-parse --short HEAD 2>$null)
    $dirty = (& git status --short 2>$null)

    Write-Host "Prettyscope local plugin status"
    if ($commit) {
        Write-Host "Repo: $repoRoot"
        Write-Host "Git: $branch $commit"
        if ($dirty) {
            Write-Host "Worktree: dirty"
        }
        else {
            Write-Host "Worktree: clean"
        }
    }
    else {
        Write-Host "Repo: $repoRoot"
        Write-Host "Git: unavailable"
    }
    Write-Host ""

    Write-Host "Build artifacts"
    Write-ArtifactStatus "Built CLAP" (Join-Path $assetRoot "CLAP\Prettyscope.clap")
    Write-ArtifactStatus "Built VST3" (Join-Path $assetRoot "VST3\Prettyscope.vst3")
    Write-ArtifactStatus "Built Standalone" (Join-Path $assetRoot "Standalone-prettyscope-clap_standalone\Prettyscope.exe")
    Write-Host ""

    Write-Host "Installed user-local artifacts"
    Write-ArtifactStatus "Installed CLAP" (Join-Path $env:LOCALAPPDATA "Programs\Common\CLAP\Prettyscope.clap")
    Write-ArtifactStatus "Installed VST3" (Join-Path $env:LOCALAPPDATA "Programs\Common\VST3\Prettyscope.vst3")
    Write-Host ""

    Write-Host "Install freshness"
    Write-InstallComparison `
        "CLAP" `
        (Join-Path $assetRoot "CLAP\Prettyscope.clap") `
        (Join-Path $env:LOCALAPPDATA "Programs\Common\CLAP\Prettyscope.clap")
    Write-InstallComparison `
        "VST3" `
        (Join-Path $assetRoot "VST3\Prettyscope.vst3") `
        (Join-Path $env:LOCALAPPDATA "Programs\Common\VST3\Prettyscope.vst3")
}
finally {
    Pop-Location
}
