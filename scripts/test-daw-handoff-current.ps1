param(
    [string] $BuildDir = "build-tracer",
    [switch] $RequireCurrent,
    [switch] $Quiet,
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

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

function Add-Issue {
    param([string] $Message)

    $issues.Add($Message) | Out-Null
}

Push-Location $repoRoot
try {
    $currentCommit = (& git rev-parse --short HEAD 2>$null)
    $artifacts = & (Join-Path $PSScriptRoot "show-latest-daw-test-artifacts.ps1") `
        -BuildDir $BuildDir `
        -Quiet `
        -PassThru

    $issues = New-Object System.Collections.Generic.List[string]
    $reportCommit = ""
    if (!$artifacts.ReportPath -or !(Test-Path $artifacts.ReportPath)) {
        Add-Issue "Latest DAW report is missing."
    }
    else {
        $reportLines = Get-Content -Path $artifacts.ReportPath
        $reportCommit = Get-ReportField -Lines $reportLines -Field "Prettyscope commit"
        if (!$reportCommit) {
            Add-Issue "Latest DAW report has no Prettyscope commit field."
        }
        elseif ($currentCommit -and $reportCommit -ne $currentCommit) {
            Add-Issue "Latest DAW report commit $reportCommit does not match current commit $currentCommit."
        }
    }

    if (!$artifacts.SummaryPath -or !(Test-Path $artifacts.SummaryPath)) {
        Add-Issue "Latest release summary is missing."
    }
    if (!$artifacts.AnswerSheetPath -or !(Test-Path $artifacts.AnswerSheetPath)) {
        Add-Issue "Latest DAW answer sheet is missing."
    }
    if (!$artifacts.BundleDirectory -or !(Test-Path $artifacts.BundleDirectory)) {
        Add-Issue "Latest DAW bundle folder is missing."
    }
    if (!$artifacts.BundleZipPath -or !(Test-Path $artifacts.BundleZipPath)) {
        Add-Issue "Latest DAW bundle zip is missing."
    }

    $current = $issues.Count -eq 0

    if ($PassThru) {
        [PSCustomObject]@{
            Current = $current
            IssueCount = $issues.Count
            Issues = $issues.ToArray()
            CurrentCommit = $currentCommit
            ReportCommit = $reportCommit
            ReportPath = $artifacts.ReportPath
            AnswerSheetPath = $artifacts.AnswerSheetPath
            SummaryPath = $artifacts.SummaryPath
            BundleDirectory = $artifacts.BundleDirectory
            BundleZipPath = $artifacts.BundleZipPath
        }
    }

    if (!$Quiet) {
        Write-Host "Reviewed Prettyscope DAW handoff currency"
        Write-Host "  Current commit: $currentCommit"
        Write-Host "  Report commit:  $reportCommit"
        Write-Host "  Report:         $($artifacts.ReportPath)"
        Write-Host "  Answer sheet:   $($artifacts.AnswerSheetPath)"
        Write-Host "  Summary:        $($artifacts.SummaryPath)"
        Write-Host "  Bundle folder:  $($artifacts.BundleDirectory)"
        Write-Host "  Bundle zip:     $($artifacts.BundleZipPath)"

        if ($current) {
            Write-Host "DAW handoff is current."
        }
        else {
            Write-Host "DAW handoff review found $($issues.Count) issue(s):"
            foreach ($issue in $issues) {
                Write-Host "  - $issue"
            }
        }
    }

    if ($RequireCurrent -and !$current) {
        exit 1
    }
}
finally {
    Pop-Location
}
