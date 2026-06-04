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
Require-Text "DAW testing still required" '## DAW Testing Still Required'
Require-Text "host matrix" 'Host coverage is tracked in `docs\\DAW_HOST_MATRIX\.md`'
Require-Text "completed report submit" 'submit-daw-test-report\.ps1'

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
