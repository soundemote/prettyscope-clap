param(
    [string] $BuildDir = "build-tracer",
    [string] $MatrixPath = "",
    [switch] $IncludeBuildScratch,
    [switch] $IncludeSmokeReports,
    [switch] $DocsOnlyReports,
    [switch] $OpenReport
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$MatrixPath) {
    $MatrixPath = Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md"
}
$resolvedMatrixPath = if (Test-Path $MatrixPath) {
    (Resolve-Path $MatrixPath).Path
}
else {
    $MatrixPath
}
$defaultMatrixPath = (Resolve-Path (Join-Path $repoRoot "docs\DAW_HOST_MATRIX.md")).Path
$scanBuildScratch = ([bool] $IncludeBuildScratch) -or !$DocsOnlyReports

function Resolve-ReportPath {
    param([string] $Path)

    if (!$Path) {
        return ""
    }
    if (Test-Path $Path) {
        return (Resolve-Path $Path).Path
    }

    $candidate = Join-Path $repoRoot $Path
    if (Test-Path $candidate) {
        return (Resolve-Path $candidate).Path
    }

    return ""
}

function Read-MatrixRows {
    param([string] $Path)

    if (!(Test-Path $Path)) {
        return @()
    }

    return @(Get-Content -Path $Path | Where-Object {
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
                ResolvedReportPath = Resolve-ReportPath $cells[4]
            }
        })
}

function Format-PathOrMissing {
    param([string] $Path)

    if (!$Path) {
        return "(none found)"
    }

    return $Path
}

function Format-LatestReviewCommand {
    $command = "powershell -ExecutionPolicy Bypass -File .\scripts\review-latest-daw-test-report.ps1 -RequireComplete"
    if ($BuildDir -ne "build-tracer") {
        $command += " -BuildDir `"$BuildDir`""
    }
    if ($DocsOnlyReports) {
        $command += " -DocsOnlyReports"
    }
    return $command
}

function Format-LatestSubmitCommand {
    param([switch] $Preview)

    $command = "powershell -ExecutionPolicy Bypass -File .\scripts\submit-latest-daw-test-report.ps1"
    if ($Preview) {
        $command += " -Preview"
    }
    if ($BuildDir -ne "build-tracer") {
        $command += " -BuildDir `"$BuildDir`""
    }
    if ($DocsOnlyReports) {
        $command += " -DocsOnlyReports"
    }
    if ($resolvedMatrixPath -ne $defaultMatrixPath) {
        $command += " -MatrixPath `"$resolvedMatrixPath`""
    }
    return $command
}

function Format-TestPrepCommand {
    return "powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-readiness.ps1 -Format CLAP -Daw `"Your DAW`" -Tester `"Your Name`""
}

Push-Location $repoRoot
try {
    $currentCommit = (& git rev-parse --short HEAD 2>$null)
    $latestArtifacts = & (Join-Path $PSScriptRoot "show-latest-daw-test-artifacts.ps1") `
        -BuildDir $BuildDir `
        -IncludeSmokeReports:$IncludeSmokeReports `
        -Quiet `
        -PassThru
    $reports = @(& (Join-Path $PSScriptRoot "show-daw-test-report-index.ps1") `
            -BuildDir $BuildDir `
            -IncludeBuildScratch:$scanBuildScratch `
            -IncludeSmokeReports:$IncludeSmokeReports `
            -Quiet `
            -PassThru)
    $matrixRows = Read-MatrixRows -Path $MatrixPath
    $submittedReportPaths = @{}
    foreach ($row in $matrixRows) {
        if ($row.ResolvedReportPath) {
            $submittedReportPaths[$row.ResolvedReportPath.ToLowerInvariant()] = $true
        }
    }

    $incompleteReports = @($reports | Where-Object { $_.Complete -eq "no" })
    if ($incompleteReports.Count -gt 0) {
        $latest = $incompleteReports | Sort-Object Modified -Descending | Select-Object -First 1
        if ($currentCommit -and $latest.Commit -and $latest.Commit -ne $currentCommit) {
            Write-Host "Next DAW test action: refresh the DAW test package."
            Write-Host "  Latest incomplete report commit: $($latest.Commit)"
            Write-Host "  Current repo commit:             $currentCommit"
            Write-Host "  Report: $($latest.Path)"
            Write-Host ""
            Write-Host "Prep command:"
            Write-Host "  $(Format-TestPrepCommand)"
            return
        }

        Write-Host "Next DAW test action: fill the latest incomplete report."
        Write-Host "  Report: $($latest.Path)"
        Write-Host "  Issues: $($latest.Issues)"
        Write-Host ""
        Write-Host "Latest grouped artifacts:"
        Write-Host "  Report:        $(Format-PathOrMissing $latestArtifacts.ReportPath)"
        Write-Host "  Summary:       $(Format-PathOrMissing $latestArtifacts.SummaryPath)"
        Write-Host "  Manifest:      $(Format-PathOrMissing $latestArtifacts.ManifestPath)"
        Write-Host "  Bundle folder: $(Format-PathOrMissing $latestArtifacts.BundleDirectory)"
        Write-Host "  Bundle zip:    $(Format-PathOrMissing $latestArtifacts.BundleZipPath)"
        Write-Host ""
        Write-Host "Review command:"
        Write-Host "  $(Format-LatestReviewCommand)"
        Write-Host ""
        Write-Host "Gap summary command:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-gaps.ps1"
        Write-Host ""
        Write-Host "Specific report review command:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\review-daw-test-report.ps1 -ReportPath `"$($latest.Path)`" -RequireComplete"
        Write-Host ""
        Write-Host "Artifact update command after exporting PNGs/preset/session:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-artifacts.ps1 -ReportPath `"$($latest.Path)`" -Dot1GeneratedPng `"path\to\dot1-generated.png`" -Dot1LoadedPng `"path\to\dot1-loaded.png`" -Dot2GeneratedPng `"path\to\dot2-generated.png`" -Dot2LoadedPng `"path\to\dot2-loaded.png`" -PresetPath `"path\to\preset`" -SessionPath `"path\to\session`""
        Write-Host ""
        Write-Host "Result/note update command examples:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath `"$($latest.Path)`" -ResultArea `"Scope follows input signal`" -PassFail pass -ResultNotes `"Trace follows the test signal.`""
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath `"$($latest.Path)`" -VisualNoteField `"Trace appearance`" -VisualNote `"No reset line or dotted endpoints observed.`""
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath `"$($latest.Path)`" -ReadyForNextVisualPolish yes -NeedsCodeFixBeforeMoreTesting no -HighestPriorityFollowUp `"Continue visual polish.`""
        Write-Host ""
        Write-Host "Open commands:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\open-daw-test-handoff.ps1"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-next-action.ps1 -OpenReport"
        if ($latestArtifacts.SummaryPath) {
            Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\show-latest-daw-test-artifacts.ps1 -OpenSummary"
        }
        if ($latestArtifacts.BundleDirectory) {
            Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\show-latest-daw-test-artifacts.ps1 -OpenBundleFolder"
        }
        if ($OpenReport) {
            Invoke-Item -LiteralPath $latest.Path
            Write-Host "Opened report: $($latest.Path)"
        }
        return
    }

    $completeReports = @($reports | Where-Object { $_.Complete -eq "yes" })
    $unsubmittedCompleteReports = @($completeReports | Where-Object {
            !$submittedReportPaths.ContainsKey($_.Path.ToLowerInvariant())
        })
    if ($unsubmittedCompleteReports.Count -gt 0) {
        $latest = $unsubmittedCompleteReports | Sort-Object Modified -Descending | Select-Object -First 1
        Write-Host "Next DAW test action: submit the latest completed report."
        Write-Host "  Report: $($latest.Path)"
        Write-Host "  Result: $($latest.Result)"
        Write-Host ""
        Write-Host "Latest grouped artifacts:"
        Write-Host "  Report:        $(Format-PathOrMissing $latestArtifacts.ReportPath)"
        Write-Host "  Summary:       $(Format-PathOrMissing $latestArtifacts.SummaryPath)"
        Write-Host "  Manifest:      $(Format-PathOrMissing $latestArtifacts.ManifestPath)"
        Write-Host "  Bundle folder: $(Format-PathOrMissing $latestArtifacts.BundleDirectory)"
        Write-Host "  Bundle zip:    $(Format-PathOrMissing $latestArtifacts.BundleZipPath)"
        Write-Host ""
        Write-Host "Preview command:"
        Write-Host "  $(Format-LatestSubmitCommand -Preview)"
        Write-Host ""
        Write-Host "Submit command:"
        Write-Host "  $(Format-LatestSubmitCommand)"
        Write-Host ""
        Write-Host "Specific report submit commands:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath `"$($latest.Path)`" -Preview"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath `"$($latest.Path)`""
        Write-Host ""
        Write-Host "Open commands:"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\open-daw-test-handoff.ps1"
        Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-next-action.ps1 -OpenReport"
        if ($latestArtifacts.SummaryPath) {
            Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\show-latest-daw-test-artifacts.ps1 -OpenSummary"
        }
        if ($latestArtifacts.BundleDirectory) {
            Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\show-latest-daw-test-artifacts.ps1 -OpenBundleFolder"
        }
        if ($OpenReport) {
            Invoke-Item -LiteralPath $latest.Path
            Write-Host "Opened report: $($latest.Path)"
        }
        return
    }

    $releaseGates = & (Join-Path $PSScriptRoot "show-daw-release-gates.ps1") `
        -MatrixPath $MatrixPath `
        -Quiet `
        -PassThru
    if ($releaseGates.Ready) {
        Write-Host "Next DAW test action: first-pass release gates are ready."
        Write-Host ""
        Write-Host "Review command:"
        $dashboardCommand = "powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-dashboard.ps1"
        if ($resolvedMatrixPath -ne $defaultMatrixPath) {
            $dashboardCommand += " -MatrixPath `"$resolvedMatrixPath`""
        }
        Write-Host "  $dashboardCommand"
        return
    }

    Write-Host "Next DAW test action: prepare a first DAW test package."
    Write-Host "  Release gates still need pass-ready DAW evidence."
    Write-Host ""
    Write-Host "Prep command:"
    Write-Host "  $(Format-TestPrepCommand)"
}
finally {
    Pop-Location
}
