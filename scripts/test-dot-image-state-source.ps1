param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$patchPath = Join-Path $repoRoot "src\engine\patch.h"
$enginePath = Join-Path $repoRoot "src\engine\engine.cpp"
$engineHeaderPath = Join-Path $repoRoot "src\engine\engine.h"
$presetManagerPath = Join-Path $repoRoot "src\presets\preset-manager.cpp"
$editorPath = Join-Path $repoRoot "src\ui\plugin-editor.cpp"
$codecPath = Join-Path $repoRoot "src\ui\dot-image-codec.cpp"
$codecHeaderPath = Join-Path $repoRoot "src\ui\dot-image-codec.h"
$testsPath = Join-Path $repoRoot "tests\dsp_basics.cpp"
$manifestPath = Join-Path $repoRoot "docs\VISUAL_CONTROL_MANIFEST.md"
$auditPath = Join-Path $repoRoot "docs\RELEASE_READINESS_AUDIT.md"

$paths = @(
    $patchPath,
    $enginePath,
    $engineHeaderPath,
    $presetManagerPath,
    $editorPath,
    $codecPath,
    $codecHeaderPath,
    $testsPath,
    $manifestPath,
    $auditPath
)

foreach ($path in $paths) {
    if (!(Test-Path $path)) {
        throw "Missing required file: $path"
    }
}

$patch = Get-Content -Raw -Path $patchPath
$engine = Get-Content -Raw -Path $enginePath
$engineHeader = Get-Content -Raw -Path $engineHeaderPath
$presetManager = Get-Content -Raw -Path $presetManagerPath
$editor = Get-Content -Raw -Path $editorPath
$codec = Get-Content -Raw -Path $codecPath
$codecHeader = Get-Content -Raw -Path $codecHeaderPath
$tests = Get-Content -Raw -Path $testsPath
$manifest = Get-Content -Raw -Path $manifestPath
$audit = Get-Content -Raw -Path $auditPath
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

Require-Text "max dot image dimension constant" $codecHeader 'inline constexpr int kMaxDotImageDimension = 512;'
Require-Text "dot image normalization API" $codecHeader 'juce::Image normalizeDotImageForState\(const juce::Image &image\);'
Require-Text "dot image PNG base64 encode API" $codecHeader 'std::string imageToPngBase64\(const juce::Image &image\);'
Require-Text "dot image PNG base64 decode API" $codecHeader 'juce::Image imageFromPngBase64\(const std::string &base64\);'
Require-Text "oversize image scale bound" $codec 'static_cast<float>\(kMaxDotImageDimension\) / static_cast<float>\(std::max\(width, height\)\)'
Require-Text "PNG base64 encoder uses normalization" $codec 'auto normalized = normalizeDotImageForState\(image\);'
Require-Text "PNG base64 decoder normalizes loaded image" $codec 'return normalizeDotImageForState\(\s*juce::ImageFileFormat::loadFrom\(block\.getData\(\), block\.getSize\(\)\)\);'

Require-Text "visual asset dot image label state" $patch 'std::string label\{"Generated"\};'
Require-Text "visual asset dot image PNG payload state" $patch 'std::string pngBase64;'
Require-Text "visual asset state reset" $patch 'void reset\(\)\s*\{\s*for \(auto &dot : dotImages\)'
Require-Text "visual assets saved into patch XML" $patch 'TiXmlElement assets\("visualAssets"\);'
Require-Text "visual asset dot XML element" $patch 'TiXmlElement dot\("dotImage"\);'
Require-Text "visual asset label XML attribute" $patch 'dot\.SetAttribute\("label", source\.label\.c_str\(\)\);'
Require-Text "visual asset PNG XML payload" $patch 'dot\.InsertEndChild\(TiXmlText\(source\.pngBase64\.c_str\(\)\)\);'
Require-Text "visual assets restored from patch XML" $patch 'auto \*assets = root->FirstChildElement\("visualAssets"\);'
Require-Text "visual asset label restore" $patch 'target\.label = label;'
Require-Text "visual asset PNG restore" $patch 'target\.pngBase64 = text->Value\(\) \? text->Value\(\) : "";'

Require-Text "visual asset message definition" $engineHeader 'std::shared_ptr<Patch::VisualAssetState> visualAssets;'
Require-Text "engine consumes visual asset messages" $engine 'patch\.visualAssets = \*uiM->visualAssets;'
Require-Text "preset load sends visual assets to engine" $presetManager 'std::make_shared<Patch::VisualAssetState>\(patch\.visualAssets\)'

Require-Text "editor load normalizes image" $editor 'auto image = normalizeDotImageForState\(juce::ImageFileFormat::loadFrom\(file\)\);'
Require-Text "editor load records filename label" $editor 'dot\.label = file\.getFileName\(\);'
Require-Text "editor syncs image into patch base64" $editor 'target\.pngBase64 = imageToPngBase64\(source\.image\);'
Require-Text "editor sends visual assets to engine" $editor 'std::make_shared<Patch::VisualAssetState>\(patchCopy\.visualAssets\)'
Require-Text "editor restores image from patch base64" $editor 'target\.image = imageFromPngBase64\(source\.pngBase64\);'
Require-Text "editor restore increments revision" $editor 'target\.revision\+\+;'
Require-Text "editor clear resets generated label" $editor 'dot\.label = "Generated";'
Require-Text "editor refreshes renderer dot images" $editor 'scopeOpenGLView->setDotImages\(currentScopeDotImages\(\)\);'

Require-Text "patch state dot image roundtrip test" $tests 'Prettyscope dot image assets roundtrip through patch state'
Require-Text "missing patch state resets dot images test" $tests 'Prettyscope dot image assets reset when absent from patch state'
Require-Text "bounded dot image codec test" $tests 'Prettyscope dot image codec bounds oversized image state'
Require-Text "engine visual asset queue test" $tests 'visualAssets != nullptr'

Require-Text "manifest state payload expectation" $manifest 'Loaded image labels and PNG payloads are stored in patch/plugin state'
Require-Text "audit state persistence expectation" $audit 'Dot image labels and PNG payloads are stored in patch XML state'
Require-Text "audit source verifier coverage" $audit 'dot-image state source verifier'

if ($PassThru) {
    [PSCustomObject]@{
        PatchPath = (Resolve-Path $patchPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope dot-image state source"
Write-Host "  Patch: $patchPath"

if ($issues.Count -eq 0) {
    Write-Host "Dot-image state source covers PNG payload persistence and restore wiring."
    exit 0
}

Write-Host "Dot-image state source review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
