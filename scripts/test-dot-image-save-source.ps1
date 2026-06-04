param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$editorPath = Join-Path $repoRoot "src\ui\plugin-editor.cpp"
$mainPanelPath = Join-Path $repoRoot "src\ui\main-panel.cpp"
$manifestPath = Join-Path $repoRoot "docs\VISUAL_CONTROL_MANIFEST.md"
$auditPath = Join-Path $repoRoot "docs\RELEASE_READINESS_AUDIT.md"
$checklistPath = Join-Path $repoRoot "docs\DAW_TEST_CHECKLIST.md"

foreach ($path in @($editorPath, $mainPanelPath, $manifestPath, $auditPath, $checklistPath)) {
    if (!(Test-Path $path)) {
        throw "Missing required file: $path"
    }
}

$editor = Get-Content -Raw -Path $editorPath
$mainPanel = Get-Content -Raw -Path $mainPanelPath
$manifest = Get-Content -Raw -Path $manifestPath
$audit = Get-Content -Raw -Path $auditPath
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

Require-Text "Save button invokes editor save handler" $mainPanel 'save->onClick = \[this, i\]\(\) \{ editor\.saveDotImage\(i\); \};'
Require-Text "generated dot export function" $editor 'juce::Image createGeneratedDotImage\(const ScopeVisualState &state, size_t dotIndex\)'
Require-Text "generated dot size uses overall multiplier" $editor '\(isDot2 \? state\.dot2Size : state\.dot1Size\) \* state\.dotOverallSize'
Require-Text "generated dot halo uses overall multiplier" $editor '\(isDot2 \? state\.dot2Halo : state\.dot1Halo\) \* state\.dotOverallHalo'
Require-Text "generated dot intensity uses overall multiplier" $editor '\(isDot2 \? state\.dot2Intensity : state\.dot1Intensity\) \* state\.dotOverallIntensity'
Require-Text "generated dot aspect control" $editor 'std::clamp\(isDot2 \? state\.dot2Aspect : state\.dot1Aspect, 0\.1f, 10\.0f\)'
Require-Text "generated dot rotation control" $editor '\(isDot2 \? state\.dot2Rotation : state\.dot1Rotation\) \* pi / 180\.0f'
Require-Text "generated dot ARGB image" $editor 'juce::Image\(juce::Image::ARGB, imageSize, imageSize, true\)'
Require-Text "generated dot per-pixel write" $editor 'image\.setPixelAt\(x, y, colour\);'

Require-Text "save dot image entrypoint" $editor 'void PluginEditor::saveDotImage\(size_t dotIndex\)'
Require-Text "save default PNG extension" $editor 'auto defaultFileName = dotName\(dotIndex\)\.replaceCharacter\(.*\) \+ "\.png";'
Require-Text "save loaded image stem default" $editor 'auto stem = juce::File\(dot\.label\)\.getFileNameWithoutExtension\(\);'
Require-Text "save file chooser title" $editor '"Save " \+ dotName\(dotIndex\) \+ " Image"'
Require-Text "save file chooser PNG filter" $editor '"\*\.png"\);'
Require-Text "save appends PNG extension" $editor 'file = file\.withFileExtension\("\.png"\);'
Require-Text "save creates output stream" $editor 'auto stream = file\.createOutputStream\(\);'
Require-Text "save loaded-or-generated branch" $editor 'currentDot\.hasImage\(\) \? currentDot\.image\s+: createGeneratedDotImage\(currentScopeVisualState\(\),\s+dotIndex\);'
Require-Text "save PNG encoder" $editor 'auto png = juce::PNGImageFormat\(\);'
Require-Text "save writes PNG stream" $editor 'png\.writeImageToStream\(image, \*stream\)'
Require-Text "save encode failure warning" $editor 'Prettyscope could not encode the PNG\.'

Require-Text "manifest generated and loaded save behavior" $manifest '`Save` writes the active dot PNG: loaded/normalized override if present,\s+otherwise the current generated dot texture'
Require-Text "audit active dot image save coverage" $audit 'Save exports the generated texture in Generated mode and the loaded/normalized'
Require-Text "checklist generated save step" $checklist 'Save the generated PNG while the slot is in Generated mode'
Require-Text "checklist loaded save step" $checklist 'confirm the loaded/normalized image can be exported'
Require-Text "audit save source verifier coverage" $audit 'dot-image save source verifier'

if ($PassThru) {
    [PSCustomObject]@{
        EditorPath = (Resolve-Path $editorPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope dot-image save source"
Write-Host "  Editor: $editorPath"

if ($issues.Count -eq 0) {
    Write-Host "Dot-image save source covers generated and loaded PNG export wiring."
    exit 0
}

Write-Host "Dot-image save source review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
