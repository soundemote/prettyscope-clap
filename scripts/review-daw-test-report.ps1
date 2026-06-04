param(
    [Parameter(Mandatory = $true)]
    [string] $ReportPath,
    [switch] $Quiet,
    [switch] $PassThru,
    [switch] $RequireComplete
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $ReportPath)) {
    throw "Report file is missing: $ReportPath"
}

$resolvedReportPath = (Resolve-Path $ReportPath).Path
$lines = Get-Content -Path $resolvedReportPath
$issues = New-Object System.Collections.Generic.List[string]
$resultFailures = New-Object System.Collections.Generic.List[string]
$readyForNextVisualPolish = $false
$needsCodeFix = $false

function Add-Issue {
    param([string] $Message)

    $issues.Add($Message) | Out-Null
}

function Is-PlaceholderValue {
    param([string] $Value)

    $trimmed = $Value.Trim()
    return $trimmed.Length -eq 0 -or
        $trimmed -eq "yes / no" -or
        $trimmed -eq "CLAP / VST3" -or
        $trimmed -eq "Asset paths used:" -or
        $trimmed -eq "Asset paths/dimensions used:"
}

function Get-SectionLines {
    param([string] $SectionName)

    $heading = "## $SectionName"
    $start = -1
    for ($i = 0; $i -lt $lines.Count; ++$i) {
        if ($lines[$i].Trim() -eq $heading) {
            $start = $i + 1
            break
        }
    }

    if ($start -lt 0) {
        Add-Issue "Missing section: $heading"
        return @()
    }

    $section = New-Object System.Collections.Generic.List[string]
    for ($i = $start; $i -lt $lines.Count; ++$i) {
        if ($lines[$i].StartsWith("## ")) {
            break
        }
        $section.Add($lines[$i]) | Out-Null
    }

    return $section.ToArray()
}

$sessionRequired = @(
    "Date",
    "Tester",
    "DAW",
    "DAW version",
    "OS",
    "Plugin format tested",
    "Prettyscope commit",
    "Installed artifact path",
    "Installed artifact SHA256",
    "Audio source used"
)

$sessionLines = Get-SectionLines "Session"
foreach ($field in $sessionRequired) {
    $match = $sessionLines | Where-Object { $_ -match "^- $([regex]::Escape($field)):\s*(.*)$" } | Select-Object -First 1
    if (!$match) {
        Add-Issue "Missing session field: $field"
        continue
    }

    $value = [regex]::Match($match, "^- $([regex]::Escape($field)):\s*(.*)$").Groups[1].Value
    if (Is-PlaceholderValue $value) {
        Add-Issue "Session field is blank or placeholder: $field"
    }
}

$preflightLines = Get-SectionLines "Preflight"
foreach ($line in $preflightLines) {
    if ($line -match "^- (.+):\s*(.*)$") {
        $label = $matches[1]
        $value = $matches[2]
        if ($label -ne "Notes" -and (Is-PlaceholderValue $value)) {
            Add-Issue "Preflight field is blank or placeholder: $label"
        }
    }
}

$dotImageAssetLines = Get-SectionLines "Dot Image Test Assets"
$dotAssetContent = ($dotImageAssetLines | Where-Object {
        $trimmed = $_.Trim()
        $trimmed -match '^-\s*`[^`]+`\s+\(\d+x\d+,\s+\d+\s+bytes\)'
    })
if ($dotAssetContent.Count -eq 0) {
    Add-Issue "Dot Image Test Assets section has no generated or recorded asset paths."
}

$visualControlLines = Get-SectionLines "Visual Controls Under Test"
$requiredVisualGroups = @(
    "Signal",
    "Beam",
    "Phosphor",
    "Dot 1",
    "Dot 2",
    "Dot Overall",
    "Screen Burn"
)
foreach ($group in $requiredVisualGroups) {
    $match = $visualControlLines | Where-Object {
        $_ -match "^- $([regex]::Escape($group)):\s*(.+)$"
    } | Select-Object -First 1
    if (!$match) {
        Add-Issue "Missing visual control group: $group"
        continue
    }

    $value = [regex]::Match($match, "^- $([regex]::Escape($group)):\s*(.+)$").Groups[1].Value
    if (Is-PlaceholderValue $value) {
        Add-Issue "Visual control group is blank or placeholder: $group"
    }
}

$resultLines = Get-SectionLines "Results"
$resultRows = $resultLines | Where-Object { $_ -match "^\| [^|]+ \| [^|]* \| [^|]* \|$" -and $_ -notmatch "^\| ---" -and $_ -notmatch "^\| Area" }
if ($resultRows.Count -eq 0) {
    Add-Issue "No result rows found."
}

$requiredResultAreas = @(
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
)
$seenResultAreas = @{}
foreach ($row in $resultRows) {
    $cells = $row.Trim("|").Split("|") | ForEach-Object { $_.Trim() }
    if ($cells.Count -lt 3) {
        Add-Issue "Malformed result row: $row"
        continue
    }

    $area = $cells[0]
    $passFail = $cells[1]
    $notes = $cells[2]
    $seenResultAreas[$area] = $true
    if ($passFail.Length -eq 0) {
        Add-Issue "Missing Pass/Fail value for result: $area"
    }
    else {
        $normalizedPassFail = $passFail.ToLowerInvariant()
        if ($normalizedPassFail -notin @("pass", "fail")) {
            Add-Issue "Invalid Pass/Fail value for result ${area}: $passFail"
        }
        elseif ($normalizedPassFail -eq "fail") {
            $resultFailures.Add($area) | Out-Null
        }
    }
    if ($notes.Length -eq 0) {
        Add-Issue "Missing notes for result: $area"
    }
}
foreach ($area in $requiredResultAreas) {
    if (!$seenResultAreas.ContainsKey($area)) {
        Add-Issue "Missing required result row: $area"
    }
}

$visualNotes = Get-SectionLines "Visual Notes"
foreach ($line in $visualNotes) {
    if ($line -match "^- (.+):\s*(.*)$" -and (Is-PlaceholderValue $matches[2])) {
        Add-Issue "Visual note is blank: $($matches[1])"
    }
}

$releaseDecision = Get-SectionLines "Release Decision"
foreach ($line in $releaseDecision) {
    if ($line -match "^- (.+):\s*(.*)$" -and (Is-PlaceholderValue $matches[2])) {
        Add-Issue "Release decision is blank or placeholder: $($matches[1])"
    }
    elseif ($line -match "^- (.+):\s*(.*)$") {
        $label = $matches[1]
        $value = $matches[2].Trim().ToLowerInvariant()
        if ($label -in @("Ready for next visual polish pass", "Needs code fix before more testing")) {
            if ($value -notin @("yes", "no")) {
                Add-Issue "Release decision must be yes or no for ${label}: $($matches[2])"
            }
            elseif ($label -eq "Ready for next visual polish pass") {
                $readyForNextVisualPolish = ($value -eq "yes")
            }
            elseif ($label -eq "Needs code fix before more testing") {
                $needsCodeFix = ($value -eq "yes")
            }
        }
    }
}

$complete = ($issues.Count -eq 0)
$passed = $complete -and
    $resultFailures.Count -eq 0 -and
    $readyForNextVisualPolish -and
    !$needsCodeFix

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = $resolvedReportPath
        Complete = $complete
        Passed = $passed
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
        ResultFailureCount = $resultFailures.Count
        ResultFailures = $resultFailures.ToArray()
        ReadyForNextVisualPolish = $readyForNextVisualPolish
        NeedsCodeFix = $needsCodeFix
    }
    return
}

if (!$Quiet) {
    Write-Host "Reviewed DAW test report: $resolvedReportPath"
}
if ($issues.Count -eq 0) {
    if (!$Quiet) {
        Write-Host "Report looks complete."
        if ($passed) {
            Write-Host "Report result: pass."
        }
        else {
            Write-Host "Report result: not pass."
            if ($resultFailures.Count -gt 0) {
                Write-Host "  Failed result areas: $([string]::Join(', ', $resultFailures.ToArray()))"
            }
            if (!$readyForNextVisualPolish) {
                Write-Host "  Ready for next visual polish pass is not yes."
            }
            if ($needsCodeFix) {
                Write-Host "  Needs code fix before more testing is yes."
            }
        }
    }
    exit 0
}

if (!$Quiet) {
    Write-Host "Report review found $($issues.Count) issue(s):"
    foreach ($issue in $issues) {
        Write-Host "  - $issue"
    }
}

if ($RequireComplete) {
    exit 1
}
