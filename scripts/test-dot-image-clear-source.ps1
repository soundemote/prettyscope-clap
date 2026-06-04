param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$editorPath = Join-Path $repoRoot "src\ui\plugin-editor.cpp"
$mainPanelPath = Join-Path $repoRoot "src\ui\main-panel.cpp"
$manifestPath = Join-Path $repoRoot "docs\VISUAL_CONTROL_MANIFEST.md"
$auditPath = Join-Path $repoRoot "docs\RELEASE_READINESS_AUDIT.md"
$quickstartPath = Join-Path $repoRoot "docs\DAW_TEST_QUICKSTART.md"
$checklistPath = Join-Path $repoRoot "docs\DAW_TEST_CHECKLIST.md"

foreach ($path in @($editorPath, $mainPanelPath, $manifestPath, $auditPath, $quickstartPath, $checklistPath)) {
    if (!(Test-Path $path)) {
        throw "Missing required file: $path"
    }
}

$editor = Get-Content -Raw -Path $editorPath
$mainPanel = Get-Content -Raw -Path $mainPanelPath
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

Require-Text "Clear button invokes editor clear handler" $mainPanel 'clear->onClick = \[this, i\]\(\) \{ editor\.clearDotImageOverride\(i\); \};'
Require-Text "clear dot image entrypoint" $editor 'void PluginEditor::clearDotImageOverride\(size_t dotIndex\)'
Require-Text "clear bounds check" $editor 'if \(dotIndex >= dotImageOverrides\.size\(\)\)'
Require-Text "clear removes loaded image" $editor 'dot\.image = \{\};'
Require-Text "clear restores Generated label" $editor 'dot\.label = "Generated";'
Require-Text "clear bumps texture revision" $editor 'dot\.revision\+\+;'
Require-Text "clear syncs patch image state" $editor 'syncPatchDotImagesFromEditor\(\);'
Require-Text "clear refreshes renderer images" $editor 'refreshScopeDotImages\(\);'
Require-Text "clear refreshes status labels" $editor 'mainPanel->refreshDotImageStatus\(\);'
Require-Text "clear repaints editor" $editor 'repaint\(\);'

Require-Text "manifest clear behavior" $manifest '`Clear` returns the slot to generated mode'
Require-Text "quickstart clear step" $quickstart 'Click `Clear`'
Require-Text "quickstart clear expectation" $quickstart 'Clear returns the slot to generated mode'
Require-Text "checklist clear step" $checklist 'Click `Clear`'
Require-Text "checklist clear expectation" $checklist 'Clear returns the dot to Generated mode'
Require-Text "audit clear source verifier coverage" $audit 'dot-image clear source verifier'

if ($PassThru) {
    [PSCustomObject]@{
        EditorPath = (Resolve-Path $editorPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope dot-image clear source"
Write-Host "  Editor: $editorPath"

if ($issues.Count -eq 0) {
    Write-Host "Dot-image clear source covers generated-mode reset, state sync, and renderer refresh wiring."
    exit 0
}

Write-Host "Dot-image clear source review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
