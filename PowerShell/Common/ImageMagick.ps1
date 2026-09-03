<#
.SYNOPSIS
    Shared ImageMagick tool-resolution and metadata helpers (see .ai/CONVENTIONS.md, section 5).
.DESCRIPTION
    Dot-source this file to get Resolve-ImageMagickTool and Get-ImageMetadata. These exist so
    scripts that need image dimensions/EXIF data can shell out to the cross-platform ImageMagick
    CLI instead of the Windows-only System.Drawing.Common, without every script re-implementing
    the "which binary name does this platform actually have" probe.

    ImageMagick's CLI entry point varies by platform/package manager/version:
      - "magick"    - the canonical v7+ entry point, on every platform.
      - "identify"  - a standalone binary shipped by both v6 and v7 for read-only metadata.
      - "convert"   - the legacy v6 entry point; still common via older apt/Homebrew installs.
    Casing has also been observed to vary on case-sensitive filesystems (Linux/macOS), so those
    platforms additionally probe a small set of capitalization variants.
#>

$script:ResolvedImageMagickTool = $null

function Resolve-ImageMagickTool {
    <#
    .SYNOPSIS
        Finds whichever ImageMagick CLI entry point is installed and returns how to call it.
    .DESCRIPTION
        Probes, in order: magick, identify, convert - and on case-sensitive filesystems, common
        capitalization variants of each. The result is cached for the rest of the process.
    .EXAMPLE
        $tool = Resolve-ImageMagickTool
        & $tool.Exe identify -format "%wx%h" $file   # when $tool.Mode -eq 'magick'
    #>
    [CmdletBinding()]
    param()

    if ($script:ResolvedImageMagickTool) { return $script:ResolvedImageMagickTool }

    $candidatesByMode = [ordered]@{
        magick   = @('magick')
        identify = @('identify')
        convert  = @('convert')
    }

    if ($IsLinux -or $IsMacOS) {
        $candidatesByMode['magick']   += @('Magick', 'IMAGEMAGICK', 'ImageMagick')
        $candidatesByMode['identify'] += @('Identify')
        $candidatesByMode['convert']  += @('Convert')
    }

    $tried = @()
    foreach ($mode in $candidatesByMode.Keys) {
        foreach ($name in $candidatesByMode[$mode]) {
            $tried += $name
            $cmd = Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($cmd) {
                $script:ResolvedImageMagickTool = [pscustomobject]@{
                    Exe  = $cmd.Source
                    Mode = $mode
                }
                return $script:ResolvedImageMagickTool
            }
        }
    }

    throw "ImageMagick was not found on PATH. Tried: $($tried -join ', '). Install ImageMagick (https://imagemagick.org/) and ensure it's on PATH."
}

function Get-ImageMetadata {
    <#
    .SYNOPSIS
        Returns width, height, and EXIF DateTimeOriginal for an image file via ImageMagick.
    .PARAMETER Path
        Path to the image file.
    .EXAMPLE
        Get-ImageMetadata -Path "C:\Photos\example.jpg"
        Returns @{ Width = 4032; Height = 3024; DateTaken = [datetime]2023-05-01T12:34:56 }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $tool = Resolve-ImageMagickTool
    $format = '%w|%h|%[EXIF:DateTimeOriginal]'

    $output = switch ($tool.Mode) {
        'magick'   { & $tool.Exe identify -format $format -- $Path 2>$null }
        'identify' { & $tool.Exe -format $format -- $Path 2>$null }
        'convert'  { & $tool.Exe -- $Path -format $format info: 2>$null }
    }

    if (-not $output) {
        throw "Failed to read image metadata for '$Path' using '$($tool.Exe)' ($($tool.Mode) mode)."
    }

    $parts = $output.Split('|')
    $dateTaken = $null
    if ($parts.Count -ge 3 -and $parts[2]) {
        try {
            $dateTaken = [datetime]::ParseExact($parts[2].Trim(), 'yyyy:MM:dd HH:mm:ss', $null)
        } catch {
            $dateTaken = $null
        }
    }

    return @{
        Width     = [int]$parts[0]
        Height    = [int]$parts[1]
        DateTaken = $dateTaken
    }
}
