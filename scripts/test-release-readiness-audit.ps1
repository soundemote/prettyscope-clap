param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$auditPath = Join-Path $repoRoot "docs\RELEASE_READINESS_AUDIT.md"

if (!(Test-Path $auditPath)) {
    throw "Missing release readiness audit: $auditPath"
}

$content = Get-Content -Raw -Path $auditPath
$issues = New-Object System.Collections.Generic.List[string]

function Require-Text {
    param(
        [string] $Label,
        [string] $Pattern
    )

    if ($content -notmatch $Pattern) {
        $issues.Add("Missing audit coverage: $Label") | Out-Null
    }
}

Require-Text "objective coverage section" '## Objective Coverage'
Require-Text "Dot 1 controls" 'Dot 1 controls.*intensity, size, halo, image mix, rotation, and\s+aspect'
Require-Text "Dot 2 controls" 'Dot 2 controls.*intensity, size, halo, image mix, rotation, and\s+aspect'
Require-Text "Dot Overall controls" 'Overall dot controls multiply shared dot intensity, size, halo, and image mix'
Require-Text "Screen Burn controls" 'Screen Burn controls exist for persistence, fast decay, afterglow, and floor\s+fade'
Require-Text "active dot image save" 'Save exports the generated texture in Generated mode and the loaded/normalized\s+image when an override is active'
Require-Text "Dot image state persistence" 'Dot image labels and PNG payloads are stored in patch XML state'
Require-Text "loaded image aspect source verifier" 'dot-image renderer source verifier checks that loaded image aspect'
Require-Text "loaded image aspect preservation coverage" 'Loaded image aspect preservation'
Require-Text "dot overall source verifier" 'dot-overall renderer source verifier checks that shared intensity'
Require-Text "dot overall source verifier coverage" 'Descriptor/editor/renderer/source-verifier coverage for shared intensity'
Require-Text "screen burn source verifier" 'screen-burn renderer source verifier checks that persistence'
Require-Text "screen burn source verifier coverage" 'Descriptor/editor/renderer/source-verifier coverage for persistence'
Require-Text "DAW testing still required" '## DAW Testing Still Required'
Require-Text "host matrix" 'Host coverage is tracked in `docs\\DAW_HOST_MATRIX\.md`'
Require-Text "produced artifacts" 'DAW reports require concrete generated/loaded dot PNG export paths'
Require-Text "completed report submit" 'submit-daw-test-report\.ps1'
Require-Text "latest report submit helper" 'latest-report submit helper selects the newest completed unsubmitted report'
Require-Text "report index result labels" 'report index labels reports as `incomplete`, `pass-ready`, or\s+`fix-needed`'
Require-Text "latest report review helper" 'latest-report review helper selects the newest incomplete report'
Require-Text "completed report pass classification" 'Completed reports are only matrix `pass` candidates when all required result\s+rows pass and the release decision is pass-ready'
Require-Text "non-passing issue rows" 'Non-passing DAW reports require at least one complete issue row'
Require-Text "release gates require pass-ready evidence" 'Release gates re-read linked reports and require pass-ready evidence'
Require-Text "report classification smoke" 'report classification smoke test verifies pass-ready reports'
Require-Text "next-action routing smoke" 'next-action routing smoke test verifies incomplete-report'
Require-Text "next-action open commands" 'next-action script prints an open command for the active report'
Require-Text "handoff opener" 'DAW test handoff opener opens the latest report'
Require-Text "handoff currency verifier" 'DAW handoff currency verifier checks that the latest report'
Require-Text "stale report refresh guidance" 'next-action script recommends refreshing the DAW test package'
Require-Text "next-action build scratch default" 'next-action script and dashboard include generated readiness reports under\s+`build-tracer` by default'
Require-Text "release candidate summary" 'release candidate summary script writes a Markdown snapshot'
Require-Text "summary report index" 'release candidate summary includes the DAW report index'
Require-Text "readiness release summary" 'DAW readiness script writes a release candidate summary'
Require-Text "latest artifact summary" 'latest-artifact helper reports the release candidate summary'

if ($PassThru) {
    [PSCustomObject]@{
        AuditPath = (Resolve-Path $auditPath).Path
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope release readiness audit"
Write-Host "  Audit: $auditPath"

if ($issues.Count -eq 0) {
    Write-Host "Release readiness audit covers the required first-plugin surface."
    exit 0
}

Write-Host "Release readiness audit review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
