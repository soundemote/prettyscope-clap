param(
    [string] $OutputDir = "",
    [int] $Size = 256
)

$ErrorActionPreference = "Stop"

if ($Size -lt 64) {
    throw "Size must be at least 64 pixels."
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (!$OutputDir) {
    $OutputDir = Join-Path $repoRoot "build-tracer\daw-test-dot-images"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Add-Type -AssemblyName System.Drawing

function ClampByte {
    param([double] $Value)

    if ($Value -lt 0.0) {
        return 0
    }
    if ($Value -gt 255.0) {
        return 255
    }
    return [int][Math]::Round($Value)
}

function Save-SoftCoreDot {
    param(
        [string] $Path,
        [int] $ImageSize
    )

    $bitmap = [System.Drawing.Bitmap]::new($ImageSize, $ImageSize,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    try {
        $centre = ($ImageSize - 1) * 0.5
        $radius = $ImageSize * 0.5

        for ($y = 0; $y -lt $ImageSize; ++$y) {
            for ($x = 0; $x -lt $ImageSize; ++$x) {
                $dx = ($x - $centre) / $radius
                $dy = ($y - $centre) / $radius
                $r = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))

                $core = [Math]::Exp(-($r * $r) * 18.0)
                $halo = [Math]::Exp(-($r * $r) * 3.5)
                $alpha = ClampByte ((0.95 * $core + 0.35 * $halo) * 255.0)

                $red = ClampByte ((0.82 * $core + 0.16 * $halo) * 255.0)
                $green = ClampByte ((1.0 * $core + 0.82 * $halo) * 255.0)
                $blue = ClampByte ((0.98 * $core + 1.0 * $halo) * 255.0)

                $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $red, $green, $blue))
            }
        }

        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

function Save-AsymmetricStreakDot {
    param(
        [string] $Path,
        [int] $ImageSize
    )

    $width = $ImageSize
    $height = [Math]::Max(64, [int][Math]::Round($ImageSize * 0.5))
    $bitmap = [System.Drawing.Bitmap]::new($width, $height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    try {
        $cx = ($width - 1) * 0.5
        $cy = ($height - 1) * 0.5
        $rx = $width * 0.5
        $ry = $height * 0.5

        for ($y = 0; $y -lt $height; ++$y) {
            for ($x = 0; $x -lt $width; ++$x) {
                $nx = ($x - $cx) / $rx
                $ny = ($y - $cy) / $ry
                $streak = [Math]::Exp(-(($ny * $ny) * 28.0 + ($nx * $nx) * 2.0))
                $head = [Math]::Exp(-((($nx - 0.45) * ($nx - 0.45)) * 40.0 + ($ny * $ny) * 18.0))
                $tail = [Math]::Exp(-((($nx + 0.45) * ($nx + 0.45)) * 10.0 + ($ny * $ny) * 12.0))
                $diagonal = [Math]::Exp(-((($ny - ($nx * 0.35)) * ($ny - ($nx * 0.35))) * 70.0))

                $alpha = ClampByte ((0.45 * $streak + 0.35 * $tail + 0.85 * $head + 0.16 * $diagonal) * 255.0)
                $red = ClampByte ((0.20 * $streak + 0.92 * $head + 0.55 * $diagonal) * 255.0)
                $green = ClampByte ((0.95 * $streak + 0.80 * $tail + 0.40 * $head) * 255.0)
                $blue = ClampByte ((0.50 * $streak + 1.0 * $tail + 0.95 * $diagonal) * 255.0)

                $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $red, $green, $blue))
            }
        }

        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

$softCorePath = Join-Path $OutputDir "prettyscope-dot-soft-core.png"
$streakPath = Join-Path $OutputDir "prettyscope-dot-asymmetric-streak.png"

Save-SoftCoreDot -Path $softCorePath -ImageSize $Size
Save-AsymmetricStreakDot -Path $streakPath -ImageSize $Size

Write-Host "Created dot image test assets:"
Write-Host "  $softCorePath"
Write-Host "  $streakPath"
