param(
    [string] $BuildDir = "build-tracer",
    [int] $Limit = 20,
    [switch] $IncludeBuildScratch,
    [switch] $IncludeSmokeReports,
    [switch] $CompleteOnly,
    [switch] $IncompleteOnly,
    [switch] $OpenLatest,
    [switch] $Quiet,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

if ($CompleteOnly -and $IncompleteOnly) {
    throw "Use either -CompleteOnly or -IncompleteOnly, not both."
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$reportRoots = New-Object System.Collections.Generic.List[string]
$reportRoots.Add((Join-Path $repoRoot "docs\test-reports")) | Out-Null
if ($IncludeBuildScratch) {
    $reportRoots.Add((Join-Path $repoRoot $BuildDir)) | Out-Null
}

function Get-ReportField {
    param(
        [string[]] $Lines,
        [string] $Field
    )

    $match = $Lines | Where-Object {
        $_ -match "^- $([regex]::Escape($Field)):\s*(.*)$"
    } | Select-Object -First 1

    if (!$match) {
        return ""
    }

    return [regex]::Match($match, "^- $([regex]::Escape($Field)):\s*(.*)$").Groups[1].Value.Trim()
}

function Test-ReportComplete {
    param([string] $Path)

    return & (Join-Path $PSScriptRoot "review-daw-test-report.ps1") `
        -ReportPath $Path `
        -Quiet `
        -PassThru
}

$reports = New-Object System.Collections.Generic.List[object]
foreach ($root in $reportRoots) {
    if (!(Test-Path $root)) {
        continue
    }

    Get-ChildItem -Path $root -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $normalizedPath = $_.FullName.Replace('/', '\')
            $isDefaultBuildScratchReport = $IncludeBuildScratch -and
                $BuildDir -eq "build-tracer" -and
                $normalizedPath -match '\\build-tracer\\'
            $_.Name -match "daw-test.*\.md$" -and
            $_.Name -notmatch "bundle-manifest" -and
            ($IncludeSmokeReports -or $normalizedPath -notmatch '\\build-tracer\\.*-smoke\\') -and
            (!$isDefaultBuildScratchReport -or
                $IncludeSmokeReports -or
                $normalizedPath -match '\\build-tracer\\daw-readiness\\')
        } |
        ForEach-Object {
            $lines = Get-Content -Path $_.FullName
            $review = Test-ReportComplete -Path $_.FullName
            $result = if (!$review.Complete) {
                "incomplete"
            }
            elseif ($review.Passed) {
                "pass-ready"
            }
            else {
                "fix-needed"
            }
            $reports.Add([PSCustomObject]@{
                    Modified = $_.LastWriteTime
                    Complete = if ($review.Complete) { "yes" } else { "no" }
                    Result = $result
                    Issues = $review.IssueCount
                    Format = Get-ReportField -Lines $lines -Field "Plugin format tested"
                    Daw = Get-ReportField -Lines $lines -Field "DAW"
                    DawVersion = Get-ReportField -Lines $lines -Field "DAW version"
                    Tester = Get-ReportField -Lines $lines -Field "Tester"
                    Commit = Get-ReportField -Lines $lines -Field "Prettyscope commit"
                    Path = $_.FullName
                }) | Out-Null
        }
}

$filteredReports = @($reports | Where-Object {
        if ($CompleteOnly) {
            return $_.Complete -eq "yes"
        }
        if ($IncompleteOnly) {
            return $_.Complete -eq "no"
        }
        return $true
    })
$sortedReports = @($filteredReports | Sort-Object Modified -Descending | Select-Object -First $Limit)

if (!$Quiet) {
    Write-Host "Prettyscope DAW test reports"
    if ($sortedReports.Count -eq 0) {
        Write-Host "  (none found)"
    }
    else {
        $sortedReports |
            Format-Table -AutoSize Modified, Complete, Result, Issues, Format, Daw, DawVersion, Tester, Commit, Path |
            Out-Host
    }
}

if ($OpenLatest) {
    $latestReport = $sortedReports | Select-Object -First 1
    if (!$latestReport) {
        Write-Host "Cannot open latest report: none found"
    }
    else {
        Invoke-Item -LiteralPath $latestReport.Path
        Write-Host "Opened latest report: $($latestReport.Path)"
    }
}

if ($PassThru) {
    Write-Output $sortedReports
}
