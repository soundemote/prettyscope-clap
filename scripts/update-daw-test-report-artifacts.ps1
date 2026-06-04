param(
    [string] $BuildDir = "build-tracer",
    [string] $ReportPath = "",
    [switch] $DocsOnlyReports,
    [switch] $IncludeSmokeReports,
    [string] $Dot1GeneratedPng = "",
    [string] $Dot1LoadedPng = "",
    [string] $Dot2GeneratedPng = "",
    [string] $Dot2LoadedPng = "",
    [string] $PresetPath = "",
    [string] $SessionPath = "",
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

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

function Resolve-OptionalPathValue {
    param(
        [string] $Label,
        [string] $Value,
        [switch] $RequirePng
    )

    if (!$Value) {
        return ""
    }

    $candidate = $Value
    if (!(Test-Path $candidate)) {
        $repoCandidate = Join-Path $repoRoot $candidate
        if (Test-Path $repoCandidate) {
            $candidate = $repoCandidate
        }
    }

    if (!(Test-Path $candidate)) {
        throw "$Label path is missing: $Value"
    }

    $resolved = (Resolve-Path $candidate).Path
    if ($RequirePng -and [System.IO.Path]::GetExtension($resolved).ToLowerInvariant() -ne ".png") {
        throw "$Label must be a PNG path: $resolved"
    }

    return $resolved
}

function Set-ArtifactLine {
    param(
        [string[]] $Lines,
        [string] $Label,
        [string] $Value
    )

    if (!$Value) {
        return $Lines
    }

    $pattern = "^- $([regex]::Escape($Label)):\s*.*$"
    $replacement = "- ${Label}: $Value"
    $updated = $false
    $result = for ($i = 0; $i -lt $Lines.Count; ++$i) {
        if ($Lines[$i] -match $pattern) {
            $updated = $true
            $replacement
        }
        else {
            $Lines[$i]
        }
    }

    if (!$updated) {
        throw "Report is missing Test Artifacts Produced field: $Label"
    }

    return $result
}

$updates = @{
    "Dot 1 generated PNG export" = Resolve-OptionalPathValue "Dot 1 generated PNG export" $Dot1GeneratedPng -RequirePng
    "Dot 1 loaded PNG export" = Resolve-OptionalPathValue "Dot 1 loaded PNG export" $Dot1LoadedPng -RequirePng
    "Dot 2 generated PNG export" = Resolve-OptionalPathValue "Dot 2 generated PNG export" $Dot2GeneratedPng -RequirePng
    "Dot 2 loaded PNG export" = Resolve-OptionalPathValue "Dot 2 loaded PNG export" $Dot2LoadedPng -RequirePng
    "Preset name/path used" = Resolve-OptionalPathValue "Preset name/path used" $PresetPath
    "DAW session/project path used" = Resolve-OptionalPathValue "DAW session/project path used" $SessionPath
}

$nonEmptyUpdates = @($updates.GetEnumerator() | Where-Object { $_.Value })
if ($nonEmptyUpdates.Count -eq 0) {
    throw "No artifact values were provided."
}

if (!$ReportPath) {
    $ReportPath = Resolve-LatestReportPath
}

if (!(Test-Path $ReportPath)) {
    throw "Report file is missing: $ReportPath"
}

$resolvedReportPath = (Resolve-Path $ReportPath).Path
$lines = Get-Content -Path $resolvedReportPath
foreach ($entry in $nonEmptyUpdates) {
    $lines = Set-ArtifactLine $lines $entry.Key $entry.Value
}

Set-Content -Path $resolvedReportPath -Value $lines -Encoding UTF8

Write-Host "Updated DAW test report artifacts: $resolvedReportPath"
foreach ($entry in $nonEmptyUpdates | Sort-Object Key) {
    Write-Host "  $($entry.Key): $($entry.Value)"
}

if ($PassThru) {
    [PSCustomObject]@{
        ReportPath = $resolvedReportPath
        UpdatedFields = @($nonEmptyUpdates | Sort-Object Key | ForEach-Object { $_.Key })
    }
}
