param(
    [string] $BuildDir = "build-tracer",
    [string] $ReportPath = "",
    [switch] $DocsOnlyReports,
    [switch] $IncludeSmokeReports,
    [ValidateSet(
        "Plugin scans and loads",
        "Audio passes through",
        "Scope follows input signal",
        "Snapshot inspector shows active input",
        "Visual controls respond",
        "Dot Overall multiplies Dot 1 / Dot 2",
        "Screen Burn controls decay/persistence",
        "Dot 1 image load/save/clear",
        "Dot 2 image load/save/clear",
        "Dot image save exports generated and loaded PNGs",
        "Large image resize behavior",
        "Preset save/reload restores images",
        "DAW session save/reopen restores images",
        "Editor remains stable during close/reopen"
    )]
    [string] $ResultArea = "",
    [ValidateSet("", "pass", "fail")]
    [string] $PassFail = "",
    [string] $ResultNotes = "",
    [ValidateSet(
        "",
        "Trace appearance",
        "Screen burn feel",
        "Dot image appearance",
        "Dot image save behavior",
        "Control layout pain points",
        "Performance/frame-rate notes"
    )]
    [string] $VisualNoteField = "",
    [string] $VisualNote = "",
    [ValidateSet("", "yes", "no")]
    [string] $ReadyForNextVisualPolish = "",
    [ValidateSet("", "yes", "no")]
    [string] $NeedsCodeFixBeforeMoreTesting = "",
    [string] $HighestPriorityFollowUp = "",
    [string] $IssueSeverity = "",
    [string] $IssueArea = "",
    [string] $IssueDescription = "",
    [string] $IssueReproSteps = "",
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

function Escape-Cell {
    param([string] $Value)

    return $Value.Replace("|", "/").Trim()
}

function Update-ResultRow {
    param(
        [string[]] $Lines,
        [string] $Area,
        [string] $Result,
        [string] $Notes
    )

    if (!$Area) {
        return $Lines
    }
    if (!$Result -or !$Notes) {
        throw "Result updates require -ResultArea, -PassFail, and -ResultNotes."
    }

    $pattern = "^\| $([regex]::Escape($Area)) \| [^|]* \| [^|]* \|$"
    $replacement = "| $Area | $Result | $(Escape-Cell $Notes) |"
    $updated = $false
    $resultLines = for ($i = 0; $i -lt $Lines.Count; ++$i) {
        if ($Lines[$i] -match $pattern) {
            $updated = $true
            $replacement
        }
        else {
            $Lines[$i]
        }
    }

    if (!$updated) {
        throw "Report is missing result row: $Area"
    }

    return $resultLines
}

function Update-VisualNote {
    param(
        [string[]] $Lines,
        [string] $Field,
        [string] $Note
    )

    if (!$Field) {
        return $Lines
    }
    if (!$Note) {
        throw "Visual note updates require -VisualNoteField and -VisualNote."
    }

    $pattern = "^- $([regex]::Escape($Field)):\s*.*$"
    $replacement = "- ${Field}: $(Escape-Cell $Note)"
    $updated = $false
    $resultLines = for ($i = 0; $i -lt $Lines.Count; ++$i) {
        if ($Lines[$i] -match $pattern) {
            $updated = $true
            $replacement
        }
        else {
            $Lines[$i]
        }
    }

    if (!$updated) {
        throw "Report is missing visual note field: $Field"
    }

    return $resultLines
}

function Update-DecisionLine {
    param(
        [string[]] $Lines,
        [string] $Field,
        [string] $Value
    )

    if (!$Value) {
        return $Lines
    }

    $pattern = "^- $([regex]::Escape($Field)):\s*.*$"
    $replacement = "- ${Field}: $(Escape-Cell $Value)"
    $updated = $false
    $resultLines = for ($i = 0; $i -lt $Lines.Count; ++$i) {
        if ($Lines[$i] -match $pattern) {
            $updated = $true
            $replacement
        }
        else {
            $Lines[$i]
        }
    }

    if (!$updated) {
        throw "Report is missing release decision field: $Field"
    }

    return $resultLines
}

function Add-IssueRow {
    param(
        [string[]] $Lines,
        [string] $Severity,
        [string] $Area,
        [string] $Description,
        [string] $ReproSteps
    )

    $hasAnyIssueField = $Severity -or $Area -or $Description -or $ReproSteps
    if (!$hasAnyIssueField) {
        return $Lines
    }
    if (!$Severity -or !$Area -or !$Description -or !$ReproSteps) {
        throw "Issue updates require -IssueSeverity, -IssueArea, -IssueDescription, and -IssueReproSteps."
    }

    $insertAt = -1
    for ($i = 0; $i -lt $Lines.Count; ++$i) {
        if ($Lines[$i].Trim() -eq "## Release Decision") {
            $insertAt = $i
            break
        }
    }
    if ($insertAt -lt 0) {
        throw "Report is missing Release Decision section after Issues Found."
    }

    $row = "| $(Escape-Cell $Severity) | $(Escape-Cell $Area) | $(Escape-Cell $Description) | $(Escape-Cell $ReproSteps) |"
    $result = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Lines.Count; ++$i) {
        if ($i -eq $insertAt) {
            if ($result.Count -gt 0 -and $result[$result.Count - 1].Trim().Length -eq 0) {
                $result.RemoveAt($result.Count - 1)
            }
            $result.Add($row) | Out-Null
            $result.Add("") | Out-Null
        }
        $result.Add($Lines[$i]) | Out-Null
    }

    return $result.ToArray()
}

$hasUpdate = $ResultArea -or $VisualNoteField -or $ReadyForNextVisualPolish -or
    $NeedsCodeFixBeforeMoreTesting -or $HighestPriorityFollowUp -or
    $IssueSeverity -or $IssueArea -or $IssueDescription -or $IssueReproSteps
if (!$hasUpdate) {
    throw "No report fields were provided."
}

if (!$ReportPath) {
    $ReportPath = Resolve-LatestReportPath
}
if (!(Test-Path $ReportPath)) {
    throw "Report file is missing: $ReportPath"
}

$resolvedReportPath = (Resolve-Path $ReportPath).Path
$lines = Get-Content -Path $resolvedReportPath
$updatedFields = New-Object System.Collections.Generic.List[string]

$lines = Update-ResultRow $lines $ResultArea $PassFail $ResultNotes
if ($ResultArea) {
    $updatedFields.Add("Result: $ResultArea") | Out-Null
}

$lines = Update-VisualNote $lines $VisualNoteField $VisualNote
if ($VisualNoteField) {
    $updatedFields.Add("Visual note: $VisualNoteField") | Out-Null
}

$lines = Update-DecisionLine $lines "Ready for next visual polish pass" $ReadyForNextVisualPolish
if ($ReadyForNextVisualPolish) {
    $updatedFields.Add("Release decision: Ready for next visual polish pass") | Out-Null
}

$lines = Update-DecisionLine $lines "Needs code fix before more testing" $NeedsCodeFixBeforeMoreTesting
if ($NeedsCodeFixBeforeMoreTesting) {
    $updatedFields.Add("Release decision: Needs code fix before more testing") | Out-Null
}

$lines = Update-DecisionLine $lines "Highest-priority follow-up" $HighestPriorityFollowUp
if ($HighestPriorityFollowUp) {
    $updatedFields.Add("Release decision: Highest-priority follow-up") | Out-Null
}

$lines = Add-IssueRow $lines $IssueSeverity $IssueArea $IssueDescription $IssueReproSteps
if ($IssueSeverity -or $IssueArea -or $IssueDescription -or $IssueReproSteps) {
    $updatedFields.Add("Issue row") | Out-Null
}

Set-Content -Path $resolvedReportPath -Value $lines -Encoding UTF8

Write-Host "Updated DAW test report fields: $resolvedReportPath"
foreach ($field in $updatedFields) {
    Write-Host "  $field"
}

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = $resolvedReportPath
        UpdatedFields = $updatedFields.ToArray()
    }
}
