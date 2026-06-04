param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$matrixPath = Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md"
$allowedStatuses = @(
    "untested",
    "testing",
    "pass",
    "blocked",
    "fix needed",
    "local smoke"
)
$requiredRows = @(
    "Bitwig Studio|CLAP|Windows",
    "REAPER|CLAP|Windows",
    "REAPER|VST3|Windows",
    "Ableton Live|VST3|Windows",
    "FL Studio|VST3|Windows"
)

if (!(Test-Path $matrixPath)) {
    throw "Missing DAW host matrix: $matrixPath"
}

function Read-MatrixRows {
    param([string] $Path)

    Get-Content -Path $Path | Where-Object {
        $_ -match '^\| [^|]+ \| [^|]+ \| [^|]+ \| [^|]+ \|'
    } | Where-Object {
        $_ -notmatch '^\| Host ' -and $_ -notmatch '^\| ---'
    } | ForEach-Object {
        $cells = $_.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        [PSCustomObject]@{
            Host = $cells[0]
            Format = $cells[1]
            OS = $cells[2]
            Status = $cells[3]
            LatestReport = $cells[4]
            Notes = $cells[5]
        }
    }
}

$rows = @(Read-MatrixRows -Path $matrixPath)
$issues = New-Object System.Collections.Generic.List[string]

if ($rows.Count -eq 0) {
    $issues.Add("Host matrix contains no rows.") | Out-Null
}

$seenKeys = @{}
foreach ($row in $rows) {
    $key = "$($row.Host)|$($row.Format)|$($row.OS)"
    if ($seenKeys.ContainsKey($key)) {
        $issues.Add("Duplicate host matrix row: $key") | Out-Null
    }
    $seenKeys[$key] = $true

    if (!($allowedStatuses -contains $row.Status)) {
        $issues.Add("Invalid status '$($row.Status)' for $key") | Out-Null
    }

    if ($row.Format -notin @("CLAP", "VST3", "Standalone")) {
        $issues.Add("Invalid format '$($row.Format)' for $key") | Out-Null
    }

    if ($row.OS.Length -eq 0) {
        $issues.Add("Missing OS for $key") | Out-Null
    }

    if ($row.Status -ne "untested" -and $row.Status -ne "local smoke") {
        if ($row.LatestReport.Length -eq 0) {
            $issues.Add("Missing latest report path for tested row: $key") | Out-Null
        }
        elseif (!(Test-Path (Join-Path $repoRoot $row.LatestReport)) -and !(Test-Path $row.LatestReport)) {
            $issues.Add("Latest report path does not exist for ${key}: $($row.LatestReport)") |
                Out-Null
        }
    }
}

foreach ($required in $requiredRows) {
    if (!$seenKeys.ContainsKey($required)) {
        $issues.Add("Missing required first-pass row: $required") | Out-Null
    }
}

if ($PassThru) {
    [PSCustomObject]@{
        RowCount = $rows.Count
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope DAW host matrix"
Write-Host "  Rows: $($rows.Count)"

if ($issues.Count -eq 0) {
    Write-Host "DAW host matrix looks valid."
    exit 0
}

Write-Host "DAW host matrix review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
