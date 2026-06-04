param(
    [Parameter(Mandatory = $true)]
    [string] $ReportPath,
    [ValidateSet("testing", "pass", "blocked", "fix needed")]
    [string] $Status = "",
    [string] $Notes = "",
    [switch] $AddMissing,
    [switch] $Preview,
    [string] $MatrixPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$MatrixPath) {
    $MatrixPath = Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md"
}
if (!(Test-Path $MatrixPath)) {
    throw "Missing DAW host matrix: $MatrixPath"
}
if (!(Test-Path $ReportPath)) {
    throw "Missing DAW report: $ReportPath"
}

$resolvedMatrixPath = (Resolve-Path $MatrixPath).Path
$resolvedReportPath = (Resolve-Path $ReportPath).Path
$reportLines = Get-Content -Path $resolvedReportPath

function Get-ReportField {
    param([string] $Field)

    $match = $reportLines | Where-Object {
        $_ -match "^- $([regex]::Escape($Field)):\s*(.*)$"
    } | Select-Object -First 1

    if (!$match) {
        return ""
    }

    return [regex]::Match($match, "^- $([regex]::Escape($Field)):\s*(.*)$").Groups[1].Value.Trim()
}

function Normalize-OsForMatrix {
    param([string] $Os)

    if ($Os -match "Windows") {
        return "Windows"
    }
    if ($Os -match "macOS|Darwin") {
        return "macOS"
    }
    if ($Os -match "Linux") {
        return "Linux"
    }
    return $Os.Trim()
}

function Relative-Path-FromRepo {
    param([string] $Path)

    $full = (Resolve-Path $Path).Path
    $root = $repoRoot.Path.TrimEnd('\', '/')
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($root.Length).TrimStart('\', '/')
    }
    return $full
}

function Escape-MatrixCell {
    param([string] $Value)

    return $Value.Replace("|", "/").Trim()
}

$hostName = Get-ReportField "DAW"
$format = Get-ReportField "Plugin format tested"
$os = Normalize-OsForMatrix (Get-ReportField "OS")
if (!$hostName) {
    throw "Report is missing DAW field: $resolvedReportPath"
}
if ($format -notin @("CLAP", "VST3")) {
    throw "Report has unsupported plugin format '$format': $resolvedReportPath"
}
if (!$os) {
    throw "Report is missing OS field: $resolvedReportPath"
}

$review = & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
    -ReportPath $resolvedReportPath `
    -Quiet `
    -PassThru

$targetStatus = $Status
if (!$targetStatus) {
    $targetStatus = if ($review.Complete) { "pass" } else { "testing" }
}
if ($targetStatus -eq "pass" -and !$review.Complete) {
    throw "Cannot mark host matrix row as pass until report review is complete: $resolvedReportPath"
}

$relativeReportPath = Relative-Path-FromRepo $resolvedReportPath
$matrixNotes = if ($Notes) {
    $Notes
}
elseif ($targetStatus -eq "testing") {
    "Report started; $($review.IssueCount) incomplete field(s)."
}
else {
    "Updated from reviewed DAW report."
}

$newRow = "| $(Escape-MatrixCell $hostName) | $(Escape-MatrixCell $format) | $(Escape-MatrixCell $os) | $(Escape-MatrixCell $targetStatus) | $(Escape-MatrixCell $relativeReportPath) | $(Escape-MatrixCell $matrixNotes) |"
$lines = @(Get-Content -Path $resolvedMatrixPath)
$rowPattern = "^\| $([regex]::Escape($hostName)) \| $([regex]::Escape($format)) \| $([regex]::Escape($os)) \|"
$rowIndex = -1
for ($i = 0; $i -lt $lines.Count; ++$i) {
    if ($lines[$i] -match $rowPattern) {
        $rowIndex = $i
        break
    }
}

if ($Preview) {
    $action = if ($rowIndex -ge 0) { "update existing row" } else { "add missing row" }
    Write-Host "Preview DAW host matrix update"
    Write-Host "  Matrix: $resolvedMatrixPath"
    Write-Host "  Action: $action"
    Write-Host "  Host:   $hostName"
    Write-Host "  Format: $format"
    Write-Host "  OS:     $os"
    Write-Host "  Status: $targetStatus"
    Write-Host "  Report: $relativeReportPath"
    Write-Host "  Row:    $newRow"
    if ($rowIndex -lt 0 -and !$AddMissing) {
        Write-Host "  Note:   use -AddMissing to write this new row."
    }
    return
}

if ($rowIndex -ge 0) {
    $lines[$rowIndex] = $newRow
}
else {
    if (!$AddMissing) {
        throw "No matching matrix row for ${hostName}/${format}/${os}. Use -AddMissing to add one."
    }

    $insertIndex = -1
    for ($i = 0; $i -lt $lines.Count; ++$i) {
        if ($lines[$i] -match '^\| [^|]+ \| [^|]+ \| [^|]+ \| [^|]+ \|' -and
            $lines[$i] -notmatch '^\| Host ' -and
            $lines[$i] -notmatch '^\| ---') {
            $insertIndex = $i + 1
        }
    }
    if ($insertIndex -lt 0) {
        throw "Could not locate matrix table in $resolvedMatrixPath"
    }

    $before = @($lines[0..($insertIndex - 1)])
    $after = @($lines[$insertIndex..($lines.Count - 1)])
    $lines = @($before + $newRow + $after)
}

Set-Content -Path $resolvedMatrixPath -Value $lines -Encoding utf8

Write-Host "Updated DAW host matrix"
Write-Host "  Matrix: $resolvedMatrixPath"
Write-Host "  Host:   $hostName"
Write-Host "  Format: $format"
Write-Host "  OS:     $os"
Write-Host "  Status: $targetStatus"
Write-Host "  Report: $relativeReportPath"
