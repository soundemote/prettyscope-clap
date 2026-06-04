param(
    [Parameter(Mandatory = $true)]
    [string] $AnswerPath,
    [string] $ReportPath = "",
    [switch] $RequireComplete,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $AnswerPath)) {
    throw "Answer sheet is missing: $AnswerPath"
}

$resolvedAnswerPath = (Resolve-Path $AnswerPath).Path
$answers = Get-Content -Raw -Path $resolvedAnswerPath | ConvertFrom-Json

if (!$ReportPath) {
    $ReportPath = [string] $answers.reportPath
}
if (!$ReportPath) {
    throw "No report path was provided and the answer sheet has no reportPath."
}
if (!(Test-Path $ReportPath)) {
    throw "Report file is missing: $ReportPath"
}
$resolvedReportPath = (Resolve-Path $ReportPath).Path

function Get-String {
    param($Value)

    if ($null -eq $Value) {
        return ""
    }
    return ([string] $Value).Trim()
}

$updated = New-Object System.Collections.Generic.List[string]

$artifacts = $answers.artifacts
if ($artifacts) {
    $artifactArgs = @{
        ReportPath = $resolvedReportPath
    }
    $artifactMap = @{
        Dot1GeneratedPng = Get-String $artifacts.dot1GeneratedPng
        Dot1LoadedPng = Get-String $artifacts.dot1LoadedPng
        Dot2GeneratedPng = Get-String $artifacts.dot2GeneratedPng
        Dot2LoadedPng = Get-String $artifacts.dot2LoadedPng
        PresetPath = Get-String $artifacts.presetPath
        SessionPath = Get-String $artifacts.sessionPath
    }
    foreach ($entry in $artifactMap.GetEnumerator()) {
        if ($entry.Value) {
            $artifactArgs[$entry.Key] = $entry.Value
        }
    }

    if ($artifactArgs.Count -gt 1) {
        $artifactResult = & (Join-Path $PSScriptRoot "update-daw-test-report-artifacts.ps1") @artifactArgs -PassThru
        foreach ($field in $artifactResult.UpdatedFields) {
            $updated.Add("Artifact: $field") | Out-Null
        }
    }
}

foreach ($result in @($answers.results)) {
    $area = Get-String $result.area
    $passFail = Get-String $result.passFail
    $notes = Get-String $result.notes
    if (!$area -and !$passFail -and !$notes) {
        continue
    }
    if (!$area -or !$passFail -or !$notes) {
        throw "Result entries require area, passFail, and notes."
    }

    $fieldResult = & (Join-Path $PSScriptRoot "update-daw-test-report-fields.ps1") `
        -ReportPath $resolvedReportPath `
        -ResultArea $area `
        -PassFail $passFail `
        -ResultNotes $notes `
        -PassThru
    foreach ($field in $fieldResult.UpdatedFields) {
        $updated.Add($field) | Out-Null
    }
}

if ($answers.visualNotes) {
    foreach ($property in $answers.visualNotes.PSObject.Properties) {
        $note = Get-String $property.Value
        if (!$note) {
            continue
        }

        $fieldResult = & (Join-Path $PSScriptRoot "update-daw-test-report-fields.ps1") `
            -ReportPath $resolvedReportPath `
            -VisualNoteField $property.Name `
            -VisualNote $note `
            -PassThru
        foreach ($field in $fieldResult.UpdatedFields) {
            $updated.Add($field) | Out-Null
        }
    }
}

$decision = $answers.releaseDecision
if ($decision) {
    $decisionArgs = @{
        ReportPath = $resolvedReportPath
    }
    $ready = Get-String $decision.readyForNextVisualPolish
    $needsFix = Get-String $decision.needsCodeFixBeforeMoreTesting
    $followUp = Get-String $decision.highestPriorityFollowUp
    if ($ready) {
        $decisionArgs.ReadyForNextVisualPolish = $ready
    }
    if ($needsFix) {
        $decisionArgs.NeedsCodeFixBeforeMoreTesting = $needsFix
    }
    if ($followUp) {
        $decisionArgs.HighestPriorityFollowUp = $followUp
    }

    if ($decisionArgs.Count -gt 1) {
        $fieldResult = & (Join-Path $PSScriptRoot "update-daw-test-report-fields.ps1") @decisionArgs -PassThru
        foreach ($field in $fieldResult.UpdatedFields) {
            $updated.Add($field) | Out-Null
        }
    }
}

foreach ($issue in @($answers.issues)) {
    $severity = Get-String $issue.severity
    $area = Get-String $issue.area
    $description = Get-String $issue.description
    $reproSteps = Get-String $issue.reproSteps
    if (!$severity -and !$area -and !$description -and !$reproSteps) {
        continue
    }
    if (!$severity -or !$area -or !$description -or !$reproSteps) {
        throw "Issue entries require severity, area, description, and reproSteps."
    }

    $fieldResult = & (Join-Path $PSScriptRoot "update-daw-test-report-fields.ps1") `
        -ReportPath $resolvedReportPath `
        -IssueSeverity $severity `
        -IssueArea $area `
        -IssueDescription $description `
        -IssueReproSteps $reproSteps `
        -PassThru
    foreach ($field in $fieldResult.UpdatedFields) {
        $updated.Add($field) | Out-Null
    }
}

$review = & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
    -ReportPath $resolvedReportPath `
    -Quiet `
    -PassThru

Write-Host "Applied DAW test answer sheet: $resolvedAnswerPath"
Write-Host "  Report: $resolvedReportPath"
Write-Host "  Updated fields: $($updated.Count)"
Write-Host "  Report complete: $(if ($review.Complete) { "yes" } else { "no" })"
Write-Host "  Report result: $(if ($review.Passed) { "pass" } elseif ($review.Complete) { "not pass" } else { "incomplete" })"

if ($RequireComplete -and !$review.Complete) {
    Write-Host "  Remaining issues: $($review.IssueCount)"
    foreach ($issue in $review.Issues) {
        Write-Host "    - $issue"
    }
    exit 1
}

if ($PassThru) {
    [PSCustomObject]@{
        AnswerPath = $resolvedAnswerPath
        ReportPath = $resolvedReportPath
        UpdatedFields = $updated.ToArray()
        Review = $review
    }
}
