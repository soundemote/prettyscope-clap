param(
    [string] $MatrixPath = "",
    [switch] $OpenMatrix,
    [switch] $Quiet,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$MatrixPath) {
    $MatrixPath = Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md"
}
$matrixPath = $MatrixPath

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

if (!(Test-Path $matrixPath)) {
    throw "Missing DAW host matrix: $matrixPath"
}

$rows = @(Read-MatrixRows -Path $matrixPath)
$statusSummary = $rows | Group-Object Status | Sort-Object Name | ForEach-Object {
    [PSCustomObject]@{
        Status = $_.Name
        Count = $_.Count
    }
}
$firstPassTargets = $rows | Where-Object {
    $_.Format -in @("CLAP", "VST3") -and $_.Status -ne "local smoke"
}

if (!$Quiet) {
    Write-Host "Prettyscope DAW host matrix"
    Write-Host "  Matrix: $matrixPath"
    Write-Host "  Rows:   $($rows.Count)"
    Write-Host ""
    Write-Host "Status summary"
    $statusSummary | Format-Table -AutoSize Status, Count | Out-Host

    Write-Host "First-pass target rows"
    $firstPassTargets |
        Format-Table -AutoSize Host, Format, OS, Status, LatestReport, Notes |
        Out-Host

    Write-Host "First-pass minimum gates"
    Write-Host "  - At least one CLAP host passes scan/open/audio/editor behavior."
    Write-Host "  - At least one VST3 host passes scan/open/audio/editor behavior."
    Write-Host "  - At least one host passes preset save/reload with Dot 1 and Dot 2 images."
    Write-Host "  - At least one host passes session save/reopen with Dot 1 and Dot 2 images."
    Write-Host "  - Black OpenGL, crash, failed scan, or lost image state means fix needed."
}

if ($OpenMatrix) {
    Invoke-Item -LiteralPath $matrixPath
    Write-Host "Opened matrix: $matrixPath"
}

if ($PassThru) {
    [PSCustomObject]@{
        MatrixPath = $matrixPath
        Rows = $rows
        StatusSummary = $statusSummary
        FirstPassTargets = $firstPassTargets
    }
}
