param(
    [string] $MatrixPath = "",
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$MatrixPath) {
    $MatrixPath = Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md"
}
if (!(Test-Path $MatrixPath)) {
    throw "Missing DAW host matrix: $MatrixPath"
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

function Resolve-ReportPath {
    param([string] $Path)

    if (!$Path) {
        return $null
    }

    if (Test-Path $Path) {
        return (Resolve-Path $Path).Path
    }

    $candidate = Join-Path $repoRoot $Path
    if (Test-Path $candidate) {
        return (Resolve-Path $candidate).Path
    }

    return $null
}

function Get-ReportResult {
    param(
        [string] $ReportPath,
        [string] $Area
    )

    $lines = Get-Content -Path $ReportPath
    $row = $lines | Where-Object {
        $_ -match "^\| $([regex]::Escape($Area)) \|"
    } | Select-Object -First 1

    if (!$row) {
        return ""
    }

    $cells = $row.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
    if ($cells.Count -lt 2) {
        return ""
    }

    return $cells[1]
}

function New-Gate {
    param(
        [string] $Name,
        [bool] $Pass,
        [string] $Evidence
    )

    [PSCustomObject]@{
        Gate = $Name
        Pass = if ($Pass) { "yes" } else { "no" }
        Evidence = $Evidence
    }
}

$rows = @(Read-MatrixRows -Path $MatrixPath)
$passedRows = @($rows | Where-Object { $_.Status -eq "pass" })
$passedReports = @($passedRows | ForEach-Object {
        $reportPath = Resolve-ReportPath $_.LatestReport
        if ($reportPath) {
            [PSCustomObject]@{
                Row = $_
                ReportPath = $reportPath
            }
        }
    })

$clapRows = @($passedRows | Where-Object { $_.Format -eq "CLAP" })
$vst3Rows = @($passedRows | Where-Object { $_.Format -eq "VST3" })
$fixNeededRows = @($rows | Where-Object { $_.Status -eq "fix needed" })

$presetRows = @($passedReports | Where-Object {
        (Get-ReportResult -ReportPath $_.ReportPath -Area "Preset save/reload restores images") -match '^pass$'
    })
$sessionRows = @($passedReports | Where-Object {
        (Get-ReportResult -ReportPath $_.ReportPath -Area "DAW session save/reopen restores images") -match '^pass$'
    })

$gates = New-Object System.Collections.Generic.List[object]
$gates.Add((New-Gate "At least one CLAP host passed" ($clapRows.Count -gt 0) `
            ($(if ($clapRows.Count -gt 0) { "$($clapRows[0].Host) $($clapRows[0].Format)" } else { "No pass row yet." })))) | Out-Null
$gates.Add((New-Gate "At least one VST3 host passed" ($vst3Rows.Count -gt 0) `
            ($(if ($vst3Rows.Count -gt 0) { "$($vst3Rows[0].Host) $($vst3Rows[0].Format)" } else { "No pass row yet." })))) | Out-Null
$gates.Add((New-Gate "Preset image restore passed" ($presetRows.Count -gt 0) `
            ($(if ($presetRows.Count -gt 0) { $presetRows[0].ReportPath } else { "No pass report row yet." })))) | Out-Null
$gates.Add((New-Gate "Session image restore passed" ($sessionRows.Count -gt 0) `
            ($(if ($sessionRows.Count -gt 0) { $sessionRows[0].ReportPath } else { "No pass report row yet." })))) | Out-Null
$gates.Add((New-Gate "No host row marked fix needed" ($fixNeededRows.Count -eq 0) `
            ($(if ($fixNeededRows.Count -eq 0) { "No fix-needed rows." } else { (($fixNeededRows | ForEach-Object { "$($_.Host) $($_.Format)" }) -join ", ") })))) | Out-Null

$ready = (@($gates | Where-Object { $_.Pass -ne "yes" }).Count -eq 0)

Write-Host "Prettyscope DAW first-pass release gates"
Write-Host "  Matrix: $((Resolve-Path $MatrixPath).Path)"
Write-Host "  Ready:  $(if ($ready) { "yes" } else { "no" })"
Write-Host ""
$gates | Format-Table -AutoSize Gate, Pass, Evidence | Out-Host

if ($PassThru) {
    [PSCustomObject]@{
        MatrixPath = (Resolve-Path $MatrixPath).Path
        Ready = $ready
        Gates = $gates
    }
}
