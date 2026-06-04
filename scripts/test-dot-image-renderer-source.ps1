param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$rendererPath = Join-Path $repoRoot "src\ui\phosphor-scope-renderer.cpp"
$manifestPath = Join-Path $repoRoot "docs\VISUAL_CONTROL_MANIFEST.md"
$auditPath = Join-Path $repoRoot "docs\RELEASE_READINESS_AUDIT.md"

if (!(Test-Path $rendererPath)) {
    throw "Missing renderer source: $rendererPath"
}
if (!(Test-Path $manifestPath)) {
    throw "Missing visual control manifest: $manifestPath"
}
if (!(Test-Path $auditPath)) {
    throw "Missing release readiness audit: $auditPath"
}

$renderer = Get-Content -Raw -Path $rendererPath
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

Require-Text "dot-image shader textureAspect uniform" $renderer 'uniform float textureAspect;'
Require-Text "dot-image shader source aspect clamp" $renderer 'float sourceAspect = max\(textureAspect, 0\.001\);'
Require-Text "wide source aspect sampling adjustment" $renderer 'rotated\.y \*= sourceAspect;'
Require-Text "tall source aspect sampling adjustment" $renderer 'rotated\.x /= sourceAspect;'
Require-Text "dot-image texture aspect storage" $renderer 'std::array<float, 2> textureAspects\{1\.0f, 1\.0f\};'
Require-Text "dot-image texture aspect reset" $renderer 'textureAspects\[dotIndex\] = 1\.0f;'
Require-Text "dot-image texture aspect capture" $renderer 'textureAspects\[dotIndex\] = static_cast<float>\(width\) / static_cast<float>\(height\);'
Require-Text "dot-image texture aspect uniform binding" $renderer 'glUniform1f\(glGetUniformLocation\(program, "textureAspect"\), textureAspects\[dotIndex\]\);'
Require-Text "manifest source aspect expectation" $manifest 'Loaded images should preserve their source aspect ratio'
Require-Text "audit source aspect coverage" $audit 'Loaded image aspect preservation'

if ($PassThru) {
    [PSCustomObject]@{
        RendererPath = (Resolve-Path $rendererPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope dot-image renderer source"
Write-Host "  Renderer: $rendererPath"

if ($issues.Count -eq 0) {
    Write-Host "Dot-image renderer source covers loaded-image aspect preservation."
    exit 0
}

Write-Host "Dot-image renderer source review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
