<#
.SYNOPSIS
    Reports the pixel width and height (and EXIF date, if present) of image files in a directory.

.DESCRIPTION
    Scans a directory (non-recursive) for files matching -Filter and reports each one's
    dimensions via ImageMagick. Output is written to the console.

.PARAMETER Path
    Directory to scan. Defaults to the current working directory.

.PARAMETER Filter
    Glob filter for which files to scan (Get-ChildItem -Filter syntax). Defaults to "*.jpg".
    Pass "*.png", "*.*", etc. to scan other formats - anything ImageMagick can read.

.EXAMPLE
    .\Get-ImageDimensions.ps1
    Reports dimensions for every *.jpg in the current directory.

.EXAMPLE
    .\Get-ImageDimensions.ps1 -Path "C:\Photos" -Filter "*.png"
    Reports dimensions for every PNG in C:\Photos.

.NOTES
    Prerequisites: ImageMagick (https://imagemagick.org/), any binary name/version resolvable by
    Common/ImageMagick.ps1 (magick, identify, or convert).
    Platform: Cross-platform.
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$Filter = "*.jpg",

    [Alias('h')]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true, DontShow = $true)]
    [string[]]$RemainingArguments
)

. (Join-Path -Path $PSScriptRoot -ChildPath "Common" -AdditionalChildPath "ScriptHelp.ps1")
if (Test-HelpRequested -Help:$Help -RemainingArguments $RemainingArguments) {
    Get-Help -Full $PSCommandPath
    return
}

. (Join-Path -Path $PSScriptRoot -ChildPath "Common" -AdditionalChildPath "ImageMagick.ps1")

try {
    Resolve-ImageMagickTool | Out-Null
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

$files = Get-ChildItem -LiteralPath $Path -Filter $Filter -File
if (-not $files) {
    Write-Host "No files matching '$Filter' found in '$Path'."
    exit 0
}

foreach ($file in $files) {
    try {
        $meta = Get-ImageMetadata -Path $file.FullName
        $dateText = if ($meta.DateTaken) { $meta.DateTaken.ToString('yyyy-MM-dd HH:mm:ss') } else { '(none)' }
        Write-Output "File: $($file.Name), Width: $($meta.Width), Height: $($meta.Height), DateTaken: $dateText"
    } catch {
        Write-Warning "Could not read '$($file.Name)': $($_.Exception.Message)"
    }
}
