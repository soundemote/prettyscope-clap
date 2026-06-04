param(
    [Parameter(Mandatory = $true)]
    [string] $ReportPath,
    [switch] $RequireComplete
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $ReportPath)) {
    throw "Report file is missing: $ReportPath"
}

$resolvedReportPath = (Resolve-Path $ReportPath).Path
$lines = Get-Content -Path $resolvedReportPath
$issues = New-Object System.Collections.Generic.List[string]

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

$resultLines = Get-SectionLines "Results"
$resultRows = $resultLines | Where-Object { $_ -match "^\| [^|]+ \| [^|]* \| [^|]* \|$" -and $_ -notmatch "^\| ---" -and $_ -notmatch "^\| Area" }
if ($resultRows.Count -eq 0) {
    Add-Issue "No result rows found."
}

foreach ($row in $resultRows) {
    $cells = $row.Trim("|").Split("|") | ForEach-Object { $_.Trim() }
    if ($cells.Count -lt 3) {
        Add-Issue "Malformed result row: $row"
        continue
    }

    $area = $cells[0]
    $passFail = $cells[1]
    $notes = $cells[2]
    if ($passFail.Length -eq 0) {
        Add-Issue "Missing Pass/Fail value for result: $area"
    }
    if ($notes.Length -eq 0) {
        Add-Issue "Missing notes for result: $area"
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
}

Write-Host "Reviewed DAW test report: $resolvedReportPath"
if ($issues.Count -eq 0) {
    Write-Host "Report looks complete."
    exit 0
}

Write-Host "Report review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}

if ($RequireComplete) {
    exit 1
}
