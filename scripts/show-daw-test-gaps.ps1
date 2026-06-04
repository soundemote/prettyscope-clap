param(
    [string] $BuildDir = "build-tracer",
    [string] $ReportPath = "",
    [switch] $DocsOnlyReports,
    [switch] $IncludeSmokeReports,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

function Resolve-LatestReportPath {
    $indexArgs = @{
        BuildDir = $BuildDir
        Quiet = $true
        PassThru = $true
    }
    if (!$DocsOnlyReports) {
        $indexArgs.IncludeBuildScratch = $true
    }
    if ($IncludeSmokeReports) {
        $indexArgs.IncludeSmokeReports = $true
    }

    $reports = @(& (Join-Path $PSScriptRoot "show-daw-test-report-index.ps1") @indexArgs)
    $selected = $reports |
        Where-Object { $_.Complete -eq "no" } |
        Sort-Object Modified -Descending |
        Select-Object -First 1

    if (!$selected) {
        $selected = $reports |
            Sort-Object Modified -Descending |
            Select-Object -First 1
    }

    if (!$selected) {
        throw "No DAW test reports found."
    }

    return $selected.Path
}

function Add-Unique {
    param(
        [System.Collections.Generic.List[string]] $List,
        [string] $Value
    )

    if ($Value -and !$List.Contains($Value)) {
        $List.Add($Value) | Out-Null
    }
}

if (!$ReportPath) {
    $ReportPath = Resolve-LatestReportPath
}
if (!(Test-Path $ReportPath)) {
    throw "Report file is missing: $ReportPath"
}
$resolvedReportPath = (Resolve-Path $ReportPath).Path

$review = & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
    -ReportPath $resolvedReportPath `
    -Quiet `
    -PassThru

$artifactFields = New-Object System.Collections.Generic.List[string]
$resultAreas = New-Object System.Collections.Generic.List[string]
$visualNoteFields = New-Object System.Collections.Generic.List[string]
$releaseDecisionFields = New-Object System.Collections.Generic.List[string]
$sessionFields = New-Object System.Collections.Generic.List[string]
$preflightFields = New-Object System.Collections.Generic.List[string]
$otherIssues = New-Object System.Collections.Generic.List[string]

foreach ($issue in $review.Issues) {
    if ($issue -match "^Produced artifact field is blank or placeholder: (.+)$" -or
        $issue -match "^Missing produced artifact field: (.+)$") {
        Add-Unique $artifactFields $matches[1]
    }
    elseif ($issue -match "^Missing Pass/Fail value for result: (.+)$" -or
        $issue -match "^Missing notes for result: (.+)$" -or
        $issue -match "^Invalid Pass/Fail value for result (.+):" -or
        $issue -match "^Missing required result row: (.+)$") {
        Add-Unique $resultAreas $matches[1]
    }
    elseif ($issue -match "^Visual note is blank: (.+)$") {
        Add-Unique $visualNoteFields $matches[1]
    }
    elseif ($issue -match "^Release decision is blank or placeholder: (.+)$" -or
        $issue -match "^Release decision must be yes or no for (.+):") {
        Add-Unique $releaseDecisionFields $matches[1]
    }
    elseif ($issue -match "^Session field is blank or placeholder: (.+)$" -or
        $issue -match "^Missing session field: (.+)$") {
        Add-Unique $sessionFields $matches[1]
    }
    elseif ($issue -match "^Preflight field is blank or placeholder: (.+)$") {
        Add-Unique $preflightFields $matches[1]
    }
    else {
        Add-Unique $otherIssues $issue
    }
}

if (!$PassThru) {
    Write-Host "Prettyscope DAW test gaps"
    Write-Host "  Report: $resolvedReportPath"
    Write-Host "  Complete: $(if ($review.Complete) { "yes" } else { "no" })"
    Write-Host "  Issues: $($review.IssueCount)"
    Write-Host ""

    if ($review.Complete) {
        Write-Host "Report has no missing fields."
    }
    else {
        if ($artifactFields.Count -gt 0) {
            Write-Host "Produced artifacts to record:"
            foreach ($field in $artifactFields) {
                Write-Host "  - $field"
            }
            Write-Host ""
        }

        if ($resultAreas.Count -gt 0) {
            Write-Host "Result rows to fill:"
            foreach ($area in $resultAreas) {
                Write-Host "  - $area"
            }
            Write-Host ""
        }

        if ($visualNoteFields.Count -gt 0) {
            Write-Host "Visual notes to fill:"
            foreach ($field in $visualNoteFields) {
                Write-Host "  - $field"
            }
            Write-Host ""
        }

        if ($releaseDecisionFields.Count -gt 0) {
            Write-Host "Release decisions to fill:"
            foreach ($field in $releaseDecisionFields) {
                Write-Host "  - $field"
            }
            Write-Host ""
        }

        if ($sessionFields.Count -gt 0 -or $preflightFields.Count -gt 0 -or $otherIssues.Count -gt 0) {
            Write-Host "Other report gaps:"
            foreach ($field in $sessionFields) {
                Write-Host "  - Session: $field"
            }
            foreach ($field in $preflightFields) {
                Write-Host "  - Preflight: $field"
            }
            foreach ($issue in $otherIssues) {
                Write-Host "  - $issue"
            }
            Write-Host ""
        }

        Write-Host "Useful update commands:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-artifacts.ps1 -ReportPath `"$resolvedReportPath`" -Dot1GeneratedPng `"path\to\dot1-generated.png`" -Dot1LoadedPng `"path\to\dot1-loaded.png`" -Dot2GeneratedPng `"path\to\dot2-generated.png`" -Dot2LoadedPng `"path\to\dot2-loaded.png`" -PresetPath `"path\to\preset`" -SessionPath `"path\to\session`""
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath `"$resolvedReportPath`" -ResultArea `"Scope follows input signal`" -PassFail pass -ResultNotes `"Trace follows the test signal.`""
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath `"$resolvedReportPath`" -VisualNoteField `"Trace appearance`" -VisualNote `"No reset line or dotted endpoints observed.`""
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath `"$resolvedReportPath`" -ReadyForNextVisualPolish yes -NeedsCodeFixBeforeMoreTesting no -HighestPriorityFollowUp `"Continue visual polish.`""
    }
}

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = $resolvedReportPath
        Complete = $review.Complete
        IssueCount = $review.IssueCount
        ArtifactFields = $artifactFields.ToArray()
        ResultAreas = $resultAreas.ToArray()
        VisualNoteFields = $visualNoteFields.ToArray()
        ReleaseDecisionFields = $releaseDecisionFields.ToArray()
        SessionFields = $sessionFields.ToArray()
        PreflightFields = $preflightFields.ToArray()
        OtherIssues = $otherIssues.ToArray()
        Review = $review
    }
}
