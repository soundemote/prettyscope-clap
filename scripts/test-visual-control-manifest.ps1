param(
    [switch] $PassThru
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$descriptorPath = Join-Path $repoRoot "src\scope\visual-parameters.h"
$manifestPath = Join-Path $repoRoot "docs\VISUAL_CONTROL_MANIFEST.md"

function Normalize-NumberText {
    param([string] $Value)

    $number = [double]::Parse(
        $Value.Trim().TrimEnd('f'),
        [System.Globalization.CultureInfo]::InvariantCulture)
    return $number.ToString("G15", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Read-DescriptorConstants {
    param([string] $Path)

    $constants = @{}
    Select-String -Path $Path -Pattern 'inline constexpr std::string_view\s+(\w+)\{"([^"]+)"\};' |
        ForEach-Object {
            $constants[$_.Matches[0].Groups[1].Value] = $_.Matches[0].Groups[2].Value
        }
    return $constants
}

function Read-DescriptorRows {
    param(
        [string] $Path,
        [hashtable] $Constants
    )

    $content = Get-Content -Raw -Path $Path
    $pattern = '\{(k\w+VisualParameterId),\s*\{(\d+)\},\s*"([^"]+)",\s*"([^"]+)",\s*([-\d\.]+f?),\s*([-\d\.]+f?),\s*([-\d\.]+f?),\s*([-\d\.]+f?),\s*(true|false),\s*(true|false)\}'
    return [regex]::Matches($content, $pattern) | ForEach-Object {
        $constantName = $_.Groups[1].Value
        [PSCustomObject]@{
            Id = $Constants[$constantName]
            StableId = $_.Groups[2].Value
            Display = $_.Groups[3].Value
            Category = $_.Groups[4].Value
            Default = Normalize-NumberText $_.Groups[5].Value
            Min = Normalize-NumberText $_.Groups[6].Value
            Mid = Normalize-NumberText $_.Groups[7].Value
            Max = Normalize-NumberText $_.Groups[8].Value
        }
    }
}

function Read-ManifestRows {
    param([string] $Path)

    Get-Content -Path $Path | Where-Object {
        $_ -match '^\| [^|]+ \| `[^`]+` \| \d+ \| '
    } | ForEach-Object {
        $cells = $_.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        [PSCustomObject]@{
            Category = $cells[0]
            Id = $cells[1].Trim('`')
            StableId = $cells[2]
            Display = $cells[3]
            Default = Normalize-NumberText $cells[4]
            Min = Normalize-NumberText $cells[5]
            Mid = Normalize-NumberText $cells[6]
            Max = Normalize-NumberText $cells[7]
        }
    }
}

if (!(Test-Path $descriptorPath)) {
    throw "Missing descriptor file: $descriptorPath"
}
if (!(Test-Path $manifestPath)) {
    throw "Missing visual control manifest: $manifestPath"
}

$constants = Read-DescriptorConstants -Path $descriptorPath
$descriptorRows = @(Read-DescriptorRows -Path $descriptorPath -Constants $constants)
$manifestRows = @(Read-ManifestRows -Path $manifestPath)
$manifestContent = Get-Content -Raw -Path $manifestPath
$issues = New-Object System.Collections.Generic.List[string]

function Require-ManifestText {
    param(
        [string] $Label,
        [string] $Pattern
    )

    if ($manifestContent -notmatch $Pattern) {
        $issues.Add("Missing manifest coverage: $Label") | Out-Null
    }
}

if ($descriptorRows.Count -ne $manifestRows.Count) {
    $issues.Add("Descriptor count $($descriptorRows.Count) does not match manifest count $($manifestRows.Count).") |
        Out-Null
}

$manifestById = @{}
foreach ($row in $manifestRows) {
    if ($manifestById.ContainsKey($row.Id)) {
        $issues.Add("Duplicate manifest ID: $($row.Id)") | Out-Null
        continue
    }
    $manifestById[$row.Id] = $row
}

$fields = @("StableId", "Display", "Category", "Default", "Min", "Mid", "Max")
foreach ($descriptor in $descriptorRows) {
    if (!$manifestById.ContainsKey($descriptor.Id)) {
        $issues.Add("Manifest is missing descriptor ID: $($descriptor.Id)") | Out-Null
        continue
    }

    $manifest = $manifestById[$descriptor.Id]
    foreach ($field in $fields) {
        if ($descriptor.$field -ne $manifest.$field) {
            $issues.Add("$($descriptor.Id) $field mismatch: descriptor '$($descriptor.$field)' manifest '$($manifest.$field)'") |
                Out-Null
        }
    }
}

foreach ($manifest in $manifestRows) {
    if (!($descriptorRows | Where-Object { $_.Id -eq $manifest.Id })) {
        $issues.Add("Manifest contains unknown ID: $($manifest.Id)") | Out-Null
    }
}

Require-ManifestText "non-automatable dot image workflow" '## Non-Automatable Dot Image Workflow'
Require-ManifestText "Dot 1 and Dot 2 image actions" 'For Dot 1 and Dot 2:'
Require-ManifestText "image load formats" '`Load` accepts a PNG/JPEG/BMP/GIF image'
Require-ManifestText "loaded image normalization" 'maximum 512 px longest side'
Require-ManifestText "state-persisted image payloads" 'Loaded image labels and PNG payloads are stored in patch/plugin state'
Require-ManifestText "generated and loaded save behavior" '`Save` writes the active dot PNG: loaded/normalized override if present,\s+otherwise the current generated dot texture'
Require-ManifestText "clear returns generated mode" '`Clear` returns the slot to generated mode'
Require-ManifestText "image mix blend behavior" 'Image Mix fades generated dot drawing while adding the loaded texture'
Require-ManifestText "dot overall multiplier expectation" 'Dot Overall controls should multiply Dot 1 and Dot 2 behavior together'
Require-ManifestText "screen burn finite persistence expectation" 'Screen Burn controls should change persistence without making the trace stay\s+forever'
Require-ManifestText "loaded image source aspect expectation" 'Loaded images should preserve their source aspect ratio'
Require-ManifestText "preset session restore expectation" 'Preset reload and DAW session reopen should restore loaded images and visual\s+parameter values'

if ($PassThru) {
    [PSCustomObject]@{
        DescriptorCount = $descriptorRows.Count
        ManifestCount = $manifestRows.Count
        Complete = ($issues.Count -eq 0)
        IssueCount = $issues.Count
        Issues = $issues.ToArray()
    }
    return
}

Write-Host "Reviewed Prettyscope visual control manifest"
Write-Host "  Descriptor rows: $($descriptorRows.Count)"
Write-Host "  Manifest rows:   $($manifestRows.Count)"

if ($issues.Count -eq 0) {
    Write-Host "Visual control manifest matches descriptors."
    exit 0
}

Write-Host "Visual control manifest review found $($issues.Count) issue(s):"
foreach ($issue in $issues) {
    Write-Host "  - $issue"
}
exit 1
