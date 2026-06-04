param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$rendererPath = Join-Path $repoRoot "src\ui\phosphor-scope-renderer.cpp"
$statePath = Join-Path $repoRoot "src\scope\scope-visual-state.h"
$descriptorPath = Join-Path $repoRoot "src\scope\visual-parameters.h"
$manifestPath = Join-Path $repoRoot "docs\VISUAL_CONTROL_MANIFEST.md"
$auditPath = Join-Path $repoRoot "docs\RELEASE_READINESS_AUDIT.md"

foreach ($path in @($rendererPath, $statePath, $descriptorPath, $manifestPath, $auditPath)) {
    if (!(Test-Path $path)) {
        throw "Missing required file: $path"
    }
}

$renderer = Get-Content -Raw -Path $rendererPath
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

Require-Text "screen burn persistence descriptor" $descriptors 'kScreenBurnPersistenceVisualParameterId\{"screen_burn_persistence"\}'
Require-Text "screen burn fast decay descriptor" $descriptors 'kScreenBurnFastDecayVisualParameterId\{"screen_burn_fast_decay"\}'
Require-Text "screen burn afterglow descriptor" $descriptors 'kScreenBurnAfterglowVisualParameterId\{"screen_burn_afterglow"\}'
Require-Text "screen burn floor fade descriptor" $descriptors 'kScreenBurnFloorFadeVisualParameterId\{"screen_burn_floor_fade"\}'

Require-Text "screen burn persistence state" $state 'float screenBurnPersistence\{defaultVisualFloat\(kScreenBurnPersistenceVisualParameterId, 0\.98f\)\};'
Require-Text "screen burn fast decay state" $state 'float screenBurnFastDecay\{defaultVisualFloat\(kScreenBurnFastDecayVisualParameterId, 0\.25f\)\};'
Require-Text "screen burn afterglow state" $state 'float screenBurnAfterglow\{defaultVisualFloat\(kScreenBurnAfterglowVisualParameterId, 0\.95f\)\};'
Require-Text "screen burn floor fade state" $state 'float screenBurnFloorFade\{defaultVisualFloat\(kScreenBurnFloorFadeVisualParameterId, 0\.00035f\)\};'
Require-Text "screen burn persistence clamp" $state 'clampVisualFloat\(kScreenBurnPersistenceVisualParameterId, state\.screenBurnPersistence\)'
Require-Text "screen burn fast decay clamp" $state 'clampVisualFloat\(kScreenBurnFastDecayVisualParameterId, state\.screenBurnFastDecay\)'
Require-Text "screen burn afterglow clamp" $state 'clampVisualFloat\(kScreenBurnAfterglowVisualParameterId, state\.screenBurnAfterglow\)'
Require-Text "screen burn floor fade clamp" $state 'clampVisualFloat\(kScreenBurnFloorFadeVisualParameterId, state\.screenBurnFloorFade\)'

Require-Text "decay shader persistence uniform" $renderer 'uniform float persistence;'
Require-Text "decay shader fast decay uniform" $renderer 'uniform float fastDecay;'
Require-Text "decay shader afterglow uniform" $renderer 'uniform float afterglow;'
Require-Text "decay shader floor fade uniform" $renderer 'uniform float floorFade;'
Require-Text "decay shader bright drain" $renderer 'float brightDrain = brightness \* mix\(0\.035, 0\.24, fastDecay\);'
Require-Text "decay shader tail boost" $renderer 'float tailBoost = dimTail \* mix\(0\.0, 0\.055, afterglow\) \+ softTail \* afterglow \* 0\.012;'
Require-Text "decay shader finite keep clamp" $renderer 'clamp\(persistence \+ tailBoost - brightDrain, 0\.0, mix\(0\.982, 0\.9975, afterglow\)\)'
Require-Text "decay shader floor fade subtraction" $renderer 'signal = max\(signal - vec3\(floorFade\), vec3\(0\.0\)\);'
Require-Text "screen burn persistence ratio" $renderer 'visualState\.screenBurnPersistence / 0\.98f'
Require-Text "screen burn fast decay ratio" $renderer 'visualState\.screenBurnFastDecay / 0\.25f'
Require-Text "screen burn afterglow ratio" $renderer 'visualState\.screenBurnAfterglow / 0\.95f'
Require-Text "screen burn floor fade assignment" $renderer 'params\.floorFade = visualState\.screenBurnFloorFade;'
Require-Text "decay uniform persistence binding" $renderer 'glUniform1f\(glGetUniformLocation\(decayProgram, "persistence"\), params\.persistence\);'
Require-Text "decay uniform fast decay binding" $renderer 'glUniform1f\(glGetUniformLocation\(decayProgram, "fastDecay"\), params\.fastDecay\);'
Require-Text "decay uniform afterglow binding" $renderer 'glUniform1f\(glGetUniformLocation\(decayProgram, "afterglow"\), params\.afterglow\);'
Require-Text "decay uniform floor fade binding" $renderer 'glUniform1f\(glGetUniformLocation\(decayProgram, "floorFade"\), params\.floorFade\);'

Require-Text "manifest finite screen burn expectation" $manifest 'Screen Burn controls should change persistence without making the trace stay\s+forever'
Require-Text "audit screen burn source verifier coverage" $audit 'screen-burn renderer source verifier'

if ($PassThru) {
    [PSCustomObject]@{
        RendererPath = (Resolve-Path $rendererPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope screen-burn renderer source"
Write-Host "  Renderer: $rendererPath"

if ($issues.Count -eq 0) {
    Write-Host "Screen-burn renderer source covers finite phosphor decay control wiring."
    exit 0
}

Write-Host "Screen-burn renderer source review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
