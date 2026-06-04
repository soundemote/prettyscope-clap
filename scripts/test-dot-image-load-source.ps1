param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$editorPath = Join-Path $repoRoot "src\ui\plugin-editor.cpp"
$mainPanelPath = Join-Path $repoRoot "src\ui\main-panel.cpp"
$codecHeaderPath = Join-Path $repoRoot "src\ui\dot-image-codec.h"
$manifestPath = Join-Path $repoRoot "docs\VISUAL_CONTROL_MANIFEST.md"
$auditPath = Join-Path $repoRoot "docs\RELEASE_READINESS_AUDIT.md"
$quickstartPath = Join-Path $repoRoot "docs\DAW_TEST_QUICKSTART.md"
$checklistPath = Join-Path $repoRoot "docs\DAW_TEST_CHECKLIST.md"

foreach ($path in @($editorPath, $mainPanelPath, $codecHeaderPath, $manifestPath, $auditPath, $quickstartPath, $checklistPath)) {
    if (!(Test-Path $path)) {
        throw "Missing required file: $path"
    }
}

$editor = Get-Content -Raw -Path $editorPath
$mainPanel = Get-Content -Raw -Path $mainPanelPath
$codecHeader = Get-Content -Raw -Path $codecHeaderPath
$manifest = Get-Content -Raw -Path $manifestPath
$audit = Get-Content -Raw -Path $auditPath
$quickstart = Get-Content -Raw -Path $quickstartPath
$checklist = Get-Content -Raw -Path $checklistPath
$issues = New-Object System.Collections.Generic.List[string]

function Require-Text {
    param(
        [string] $Label,
        [string] $Content,
        [string] $Pattern
    )

    if ($Content -notmatch $Pattern) {
        $issues.Add("Missing $Label") | Out-Null
    }
}

Require-Text "Load button invokes editor load handler" $mainPanel 'load->onClick = \[this, i\]\(\) \{ editor\.loadDotImageOverride\(i\); \};'
Require-Text "load dot image entrypoint" $editor 'void PluginEditor::loadDotImageOverride\(size_t dotIndex\)'
Require-Text "load bounds check" $editor 'if \(dotIndex >= dotImageOverrides\.size\(\)\)'
Require-Text "load file chooser title" $editor '"Load " \+ dotName\(dotIndex\) \+ " Image"'
Require-Text "load file chooser format filter" $editor '"\*\.png;\*\.jpg;\*\.jpeg;\*\.bmp;\*\.gif"'
Require-Text "load chooser open mode" $editor 'juce::FileBrowserComponent::canSelectFiles \| juce::FileBrowserComponent::openMode'
Require-Text "load cancelled file guard" $editor 'if \(file == juce::File\{\}\)'
Require-Text "load uses JUCE image loader" $editor 'juce::ImageFileFormat::loadFrom\(file\)'
Require-Text "load normalizes image" $editor 'auto image = normalizeDotImageForState\(juce::ImageFileFormat::loadFrom\(file\)\);'
Require-Text "normalization max dimension contract" $codecHeader 'inline constexpr int kMaxDotImageDimension = 512;'
Require-Text "load invalid image warning" $editor 'Dot Image Load Failed'
Require-Text "load stores image override" $editor 'dot\.image = image;'
Require-Text "load stores file label" $editor 'dot\.label = file\.getFileName\(\);'
Require-Text "load bumps texture revision" $editor 'dot\.revision\+\+;'
Require-Text "load syncs patch image state" $editor 'syncPatchDotImagesFromEditor\(\);'
Require-Text "load refreshes renderer images" $editor 'refreshScopeDotImages\(\);'
Require-Text "load refreshes status labels" $editor 'mainPanel->refreshDotImageStatus\(\);'
Require-Text "load repaints editor" $editor 'repaint\(\);'

Require-Text "manifest load formats" $manifest '`Load` accepts a PNG/JPEG/BMP/GIF image on the UI thread'
Require-Text "manifest load normalization" $manifest 'Loaded images are normalized to a maximum 512 px longest side'
Require-Text "quickstart load step" $quickstart 'Click `Load`'
Require-Text "checklist load step" $checklist 'Click `Load`'
Require-Text "audit load source verifier coverage" $audit 'dot-image load source verifier'

if ($PassThru) {
    [PSCustomObject]@{
        EditorPath = (Resolve-Path $editorPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope dot-image load source"
Write-Host "  Editor: $editorPath"

if ($issues.Count -eq 0) {
    Write-Host "Dot-image load source covers image format, normalization, state sync, and renderer refresh wiring."
    exit 0
}

Write-Host "Dot-image load source review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
