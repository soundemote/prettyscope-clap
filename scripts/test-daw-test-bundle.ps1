param(
    [Parameter(Mandatory = $true)]
    [string] $BundlePath,
    [switch] $RequireComplete
)

$ErrorActionPreference = "Stop"

$requiredEntries = @(
    "artifacts/CLAP/Prettyscope.clap",
    "artifacts/VST3/Prettyscope.vst3",
    "artifacts/Standalone/Prettyscope.exe",
    "README.md",
    "docs/DAW_TEST_QUICKSTART.md",
    "docs/DAW_TEST_CHECKLIST.md",
    "docs/DAW_TEST_REPORT_TEMPLATE.md",
    "docs/DAW_HOST_MATRIX.md",
    "docs/VISUAL_CONTROL_MANIFEST.md",
    "docs/PLUGIN_IDENTITY_AUDIT.md",
    "docs/RELEASE_READINESS_AUDIT.md",
    "docs/test-reports/README.md",
    "scripts/prepare-daw-test.ps1",
    "scripts/new-daw-test-report.ps1",
    "scripts/new-daw-test-bundle.ps1",
    "scripts/new-daw-test-bundle-manifest.ps1",
    "scripts/test-daw-test-bundle.ps1",
    "scripts/show-latest-daw-test-artifacts.ps1",
    "scripts/open-daw-test-handoff.ps1",
    "scripts/test-daw-handoff-current.ps1",
    "scripts/show-daw-test-report-index.ps1",
    "scripts/review-latest-daw-test-report.ps1",
    "scripts/update-daw-test-report-artifacts.ps1",
    "scripts/update-daw-test-report-fields.ps1",
    "scripts/show-daw-test-next-action.ps1",
    "scripts/show-daw-test-dashboard.ps1",
    "scripts/show-daw-host-matrix.ps1",
    "scripts/show-daw-release-gates.ps1",
    "scripts/new-release-candidate-summary.ps1",
    "scripts/update-daw-host-matrix-from-report.ps1",
    "scripts/submit-daw-test-report.ps1",
    "scripts/submit-latest-daw-test-report.ps1",
    "scripts/review-daw-test-report.ps1",
    "scripts/test-daw-report-artifact-update.ps1",
    "scripts/test-daw-report-field-update.ps1",
    "scripts/test-daw-report-classification.ps1",
    "scripts/test-daw-next-action-routing.ps1",
    "scripts/test-dot-image-renderer-source.ps1",
    "scripts/test-dot-image-clear-source.ps1",
    "scripts/test-dot-image-load-source.ps1",
    "scripts/test-dot-image-save-source.ps1",
    "scripts/test-dot-image-state-source.ps1",
    "scripts/test-dot-overall-renderer-source.ps1",
    "scripts/test-screen-burn-renderer-source.ps1",
    "scripts/test-visual-control-manifest.ps1",
    "scripts/test-release-readiness-audit.ps1",
    "scripts/test-daw-host-matrix.ps1",
    "scripts/new-dot-image-test-assets.ps1",
    "scripts/show-local-plugin-status.ps1",
    "resources/ReadmeZip.txt",
    "resources/NightlyBlurb.md",
    "resources/mac_installer/License.txt",
    "dot-image-test-assets/prettyscope-dot-soft-core.png",
    "dot-image-test-assets/prettyscope-dot-asymmetric-streak.png",
    "prettyscope-daw-test-bundle-manifest.md"
)

function Normalize-EntryPath {
    param([string] $Path)

    return $Path.Replace('\', '/').TrimStart('/')
}

function Get-FolderEntries {
    param([string] $Path)

    $root = (Resolve-Path $Path).Path
    return Get-ChildItem -Recurse -File -Path $root | ForEach-Object {
        Normalize-EntryPath $_.FullName.Substring($root.Length).TrimStart('\', '/')
    }
}

function Get-ZipEntries {
    param([string] $Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $Path).Path)
    try {
        return @($zip.Entries | Where-Object { $_.Length -gt 0 } | ForEach-Object {
                Normalize-EntryPath $_.FullName
            })
    }
    finally {
        $zip.Dispose()
    }
}

function Read-BundleTextFile {
    param(
        [string] $BundlePath,
        [string] $EntryPath
    )

    if ((Get-Item $BundlePath).PSIsContainer) {
        $filePath = Join-Path $BundlePath $EntryPath.Replace('/', '\')
        if (!(Test-Path $filePath)) {
            return ""
        }
        return Get-Content -Raw -Path $filePath
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $BundlePath).Path)
    try {
        $entry = $zip.Entries | Where-Object { (Normalize-EntryPath $_.FullName) -eq $EntryPath } |
            Select-Object -First 1
        if (!$entry) {
            return ""
        }

        $reader = [System.IO.StreamReader]::new($entry.Open())
        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $zip.Dispose()
    }
}

if (!(Test-Path $BundlePath)) {
    throw "Bundle path is missing: $BundlePath"
}

$resolvedBundlePath = (Resolve-Path $BundlePath).Path
$bundleItem = Get-Item $resolvedBundlePath
$entries = if ($bundleItem.PSIsContainer) {
    @(Get-FolderEntries $resolvedBundlePath)
}
else {
    @(Get-ZipEntries $resolvedBundlePath)
}

$entrySet = @{}
foreach ($entry in $entries) {
    $entrySet[$entry] = $true
}

$issues = New-Object System.Collections.Generic.List[string]
foreach ($required in $requiredEntries) {
    if (!$entrySet.ContainsKey($required)) {
        $issues.Add("Missing bundle entry: $required") | Out-Null
    }
}

$manifestText = Read-BundleTextFile $resolvedBundlePath "prettyscope-daw-test-bundle-manifest.md"
foreach ($needle in @(
        "Built CLAP",
        "Built VST3",
        "Built Standalone",
        "scripts\new-daw-test-bundle.ps1",
        "scripts\open-daw-test-handoff.ps1",
        "scripts\test-daw-handoff-current.ps1",
        "scripts\update-daw-test-report-artifacts.ps1",
        "scripts\update-daw-test-report-fields.ps1",
        "scripts\submit-latest-daw-test-report.ps1",
        "scripts\test-daw-report-artifact-update.ps1",
        "scripts\test-daw-report-field-update.ps1",
        "scripts\test-dot-image-renderer-source.ps1",
        "scripts\test-dot-image-clear-source.ps1",
        "scripts\test-dot-image-load-source.ps1",
        "scripts\test-dot-image-save-source.ps1",
        "scripts\test-dot-image-state-source.ps1",
        "scripts\test-dot-overall-renderer-source.ps1",
        "scripts\test-screen-burn-renderer-source.ps1")) {
    if (!$manifestText.Contains($needle)) {
        $issues.Add("Manifest does not mention: $needle") | Out-Null
    }
}

Write-Host "Reviewed DAW test bundle: $resolvedBundlePath"
if ($issues.Count -eq 0) {
    Write-Host "Bundle looks complete."
    exit 0
}

Write-Host "Bundle review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}

if ($RequireComplete) {
    exit 1
}
