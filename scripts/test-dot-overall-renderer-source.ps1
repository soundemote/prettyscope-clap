param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$rendererPath = Join-Path $repoRoot "src\ui\phosphor-scope-renderer.cpp"
$editorPath = Join-Path $repoRoot "src\ui\plugin-editor.cpp"
$statePath = Join-Path $repoRoot "src\scope\scope-visual-state.h"
$descriptorPath = Join-Path $repoRoot "src\scope\visual-parameters.h"
$manifestPath = Join-Path $repoRoot "docs\VISUAL_CONTROL_MANIFEST.md"
$auditPath = Join-Path $repoRoot "docs\RELEASE_READINESS_AUDIT.md"

foreach ($path in @($rendererPath, $editorPath, $statePath, $descriptorPath, $manifestPath, $auditPath)) {
    if (!(Test-Path $path)) {
        throw "Missing required file: $path"
    }
}

$renderer = Get-Content -Raw -Path $rendererPath
$editor = Get-Content -Raw -Path $editorPath
$state = Get-Content -Raw -Path $statePath
$descriptors = Get-Content -Raw -Path $descriptorPath
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

Require-Text "overall intensity descriptor" $descriptors 'kDotOverallIntensityVisualParameterId\{"dot_overall_intensity"\}'
Require-Text "overall size descriptor" $descriptors 'kDotOverallSizeVisualParameterId\{"dot_overall_size"\}'
Require-Text "overall halo descriptor" $descriptors 'kDotOverallHaloVisualParameterId\{"dot_overall_halo"\}'
Require-Text "overall image mix descriptor" $descriptors 'kDotOverallImageMixVisualParameterId\{"dot_overall_image_mix"\}'

Require-Text "overall intensity state" $state 'float dotOverallIntensity\{defaultVisualFloat\(kDotOverallIntensityVisualParameterId, 1\.0f\)\};'
Require-Text "overall size state" $state 'float dotOverallSize\{defaultVisualFloat\(kDotOverallSizeVisualParameterId, 1\.0f\)\};'
Require-Text "overall halo state" $state 'float dotOverallHalo\{defaultVisualFloat\(kDotOverallHaloVisualParameterId, 1\.0f\)\};'
Require-Text "overall image mix state" $state 'float dotOverallImageMix\{defaultVisualFloat\(kDotOverallImageMixVisualParameterId, 1\.0f\)\};'
Require-Text "overall intensity clamp" $state 'clampVisualFloat\(kDotOverallIntensityVisualParameterId, state\.dotOverallIntensity\)'
Require-Text "overall size clamp" $state 'clampVisualFloat\(kDotOverallSizeVisualParameterId, state\.dotOverallSize\)'
Require-Text "overall halo clamp" $state 'clampVisualFloat\(kDotOverallHaloVisualParameterId, state\.dotOverallHalo\)'
Require-Text "overall image mix clamp" $state 'clampVisualFloat\(kDotOverallImageMixVisualParameterId, state\.dotOverallImageMix\)'

Require-Text "generated dot size multiplier" $editor '\(isDot2 \? state\.dot2Size : state\.dot1Size\) \* state\.dotOverallSize'
Require-Text "generated dot halo multiplier" $editor '\(isDot2 \? state\.dot2Halo : state\.dot1Halo\) \* state\.dotOverallHalo'
Require-Text "generated dot intensity multiplier" $editor '\(isDot2 \? state\.dot2Intensity : state\.dot1Intensity\) \* state\.dotOverallIntensity'

Require-Text "renderer dot 1 halo multiplier" $renderer '\(visualState\.dot1Halo / 0\.35f\) \* visualState\.dotOverallHalo'
Require-Text "renderer dot 2 halo multiplier" $renderer '\(visualState\.dot2Halo / 0\.65f\) \* visualState\.dotOverallHalo'
Require-Text "renderer dot 1 image mix multiplier" $renderer 'visualState\.dot1ImageMix \* visualState\.dotOverallImageMix'
Require-Text "renderer dot 2 image mix multiplier" $renderer 'visualState\.dot2ImageMix \* visualState\.dotOverallImageMix'
Require-Text "renderer core width size multiplier" $renderer 'visualState\.beamTraceWidth \* visualState\.dot1Size \*\s+visualState\.dotOverallSize / 2\.0f'
Require-Text "renderer glow width size multiplier" $renderer 'visualState\.beamGlowWidth \* visualState\.dot2Size \*\s+visualState\.dotOverallSize / 6\.0f'
Require-Text "renderer core intensity multiplier" $renderer 'visualState\.dot1Intensity \*\s+visualState\.dotOverallIntensity'
Require-Text "renderer glow intensity multiplier" $renderer '\(visualState\.dot2Intensity / 0\.45f\) \*\s+visualState\.dotOverallIntensity'
Require-Text "renderer dot 2 image intensity multiplier" $renderer 'visualState\.dot2Intensity \*\s+visualState\.dotOverallIntensity'
Require-Text "renderer dot 1 image intensity multiplier" $renderer 'visualState\.dot1Intensity \*\s+visualState\.dotOverallIntensity'

Require-Text "manifest dot overall expectation" $manifest 'Dot Overall controls should multiply Dot 1 and Dot 2 behavior together'
Require-Text "audit dot overall source verifier coverage" $audit 'dot-overall renderer source verifier'

if ($PassThru) {
    [PSCustomObject]@{
        RendererPath = (Resolve-Path $rendererPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope Dot Overall renderer source"
Write-Host "  Renderer: $rendererPath"

if ($issues.Count -eq 0) {
    Write-Host "Dot Overall renderer source covers shared multiplier wiring."
    exit 0
}

Write-Host "Dot Overall renderer source review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
