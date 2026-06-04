param(
    [string] $BuildDir = "build-tracer",
    [string] $OutputDir = "",
    [string] $ZipPath = "",
    [switch] $SkipZip,
    [switch] $SkipVerify,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if (!$OutputDir) {
    $OutputDir = Join-Path $repoRoot "$BuildDir\daw-test-bundle\$timestamp-prettyscope-daw-test-bundle"
}

if (!$ZipPath) {
    $ZipPath = "$OutputDir.zip"
}

function Copy-RequiredItem {
    param(
        [string] $Source,
        [string] $Destination
    )

    if (!(Test-Path $Source)) {
        throw "Required bundle source is missing: $Source"
    }

    $parent = Split-Path -Parent $Destination
    if ($parent) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    Copy-Item -Path $Source -Destination $Destination -Recurse -Force
}

Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

    $assetRoot = Join-Path $repoRoot "$BuildDir\prettyscope-clap_assets"
    $artifactDir = Join-Path $OutputDir "artifacts"
    Copy-RequiredItem (Join-Path $assetRoot "CLAP\Prettyscope.clap") `
        (Join-Path $artifactDir "CLAP\Prettyscope.clap")
    Copy-RequiredItem (Join-Path $assetRoot "VST3\Prettyscope.vst3") `
        (Join-Path $artifactDir "VST3\Prettyscope.vst3")
    Copy-RequiredItem (Join-Path $assetRoot "Standalone-prettyscope-clap_standalone\Prettyscope.exe") `
        (Join-Path $artifactDir "Standalone\Prettyscope.exe")

    $docs = @(
        "README.md",
        "docs\DAW_TEST_QUICKSTART.md",
        "docs\DAW_TEST_CHECKLIST.md",
        "docs\DAW_TEST_REPORT_TEMPLATE.md",
        "docs\PLUGIN_IDENTITY_AUDIT.md",
        "docs\RELEASE_READINESS_AUDIT.md",
        "docs\test-reports\README.md"
    )
    foreach ($doc in $docs) {
        Copy-RequiredItem (Join-Path $repoRoot $doc) (Join-Path $OutputDir $doc)
    }

    $scripts = @(
        "scripts\prepare-daw-test.ps1",
        "scripts\new-daw-test-report.ps1",
        "scripts\review-daw-test-report.ps1",
        "scripts\new-dot-image-test-assets.ps1",
        "scripts\new-daw-test-bundle-manifest.ps1",
        "scripts\new-daw-test-bundle.ps1",
        "scripts\test-daw-test-bundle.ps1",
        "scripts\show-local-plugin-status.ps1"
    )
    foreach ($script in $scripts) {
        Copy-RequiredItem (Join-Path $repoRoot $script) (Join-Path $OutputDir $script)
    }

    $resources = @(
        "resources\ReadmeZip.txt",
        "resources\NightlyBlurb.md",
        "resources\mac_installer\License.txt"
    )
    foreach ($resource in $resources) {
        Copy-RequiredItem (Join-Path $repoRoot $resource) (Join-Path $OutputDir $resource)
    }

    $dotAssetDir = Join-Path $OutputDir "dot-image-test-assets"
    & (Join-Path $PSScriptRoot "new-dot-image-test-assets.ps1") -OutputDir $dotAssetDir | Out-Host

    $manifestPath = Join-Path $OutputDir "prettyscope-daw-test-bundle-manifest.md"
    & (Join-Path $PSScriptRoot "new-daw-test-bundle-manifest.ps1") `
        -BuildDir $BuildDir `
        -OutputPath $manifestPath | Out-Host

    $createdZipPath = $null
    if (!$SkipZip) {
        $zipParent = Split-Path -Parent $ZipPath
        if ($zipParent) {
            New-Item -ItemType Directory -Force -Path $zipParent | Out-Null
        }
        if (Test-Path $ZipPath) {
            Remove-Item -LiteralPath $ZipPath -Force
        }
        Compress-Archive -Path (Join-Path $OutputDir "*") -DestinationPath $ZipPath -Force
        $createdZipPath = (Resolve-Path $ZipPath).Path
        Write-Host "Created DAW test bundle zip: $createdZipPath"
    }

    $createdOutputDir = (Resolve-Path $OutputDir).Path
    Write-Host "Created DAW test bundle folder: $createdOutputDir"

    if (!$SkipVerify) {
        & (Join-Path $PSScriptRoot "test-daw-test-bundle.ps1") `
            -BundlePath $createdOutputDir `
            -RequireComplete | Out-Host

        if ($createdZipPath) {
            & (Join-Path $PSScriptRoot "test-daw-test-bundle.ps1") `
                -BundlePath $createdZipPath `
                -RequireComplete | Out-Host
        }
    }

    if ($PassThru) {
        [PSCustomObject]@{
            BundleDirectory = $createdOutputDir
            ZipPath = $createdZipPath
            ManifestPath = (Resolve-Path $manifestPath).Path
        }
    }
}
finally {
    Pop-Location
}
