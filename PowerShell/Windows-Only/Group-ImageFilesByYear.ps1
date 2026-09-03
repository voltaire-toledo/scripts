<#
.SYNOPSIS
    Groups image files from source subfolders into year-based subfolders under a root path.

.DESCRIPTION
    Legacy System.Drawing-based implementation, kept as a Windows-only fallback. Prefer
    PowerShell/Group-ImageFilesByYear.ps1 (cross-platform, ImageMagick-based) unless you
    specifically need this one and don't have ImageMagick installed.

    For each image file found (recursively) under the given -Subfolders beneath -Root:
      1. Appends a _WIDTHxHEIGHT dimension suffix to the filename, if not already present.
      2. Reads the image's EXIF date and moves the file into a <Year> subfolder directly under
         -Root. Files with no usable date go into an "Undetermined" subfolder.
      3. Resolves filename collisions with a _dup<n> suffix.
      4. Logs all activity to TASKS.md under -Root.

.PARAMETER Root
    Root directory: where year subfolders are created and TASKS.md is written. Required.

.PARAMETER Subfolders
    One or more subfolder names, relative to -Root, to scan recursively for images. Required.

.EXAMPLE
    .\Group-ImageFilesByYear.ps1 -Root "D:\Photos" -Subfolders "Imports","Camera"
    Groups every supported image under D:\Photos\Imports and D:\Photos\Camera into
    D:\Photos\<Year> subfolders.

.EXAMPLE
    .\Group-ImageFilesByYear.ps1 -Root "D:\Photos" -Subfolders "Imports" -WhatIf
    Previews what would be renamed/moved without changing anything.

.NOTES
    Prerequisites: .NET System.Drawing assembly (available by default on Windows).
    Supported formats: .jpg .jpeg .png .webp .bmp .tif .tiff .gif .heic
    Platform: Windows-only - System.Drawing.Common has no supported non-Windows implementation
    in modern .NET. See PowerShell/Group-ImageFilesByYear.ps1 for the cross-platform equivalent.
#>

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $false)]
    [string]$Root,

    [Parameter(Mandatory = $false)]
    [string[]]$Subfolders,

    [Alias('h')]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true, DontShow = $true)]
    [string[]]$RemainingArguments
)

. (Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath "Common", "ScriptHelp.ps1")
if (Test-HelpRequested -Help:$Help -RemainingArguments $RemainingArguments) {
    Get-Help -Full $PSCommandPath
    return
}

if (-not $Root) {
    Write-Error "Root is required. Run with -Help for usage."
    exit 1
}
if (-not $Subfolders) {
    Write-Error "Subfolders is required. Run with -Help for usage."
    exit 1
}

Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "The specified Root path does not exist or is not a directory: $Root"
}
$rootFull = (Resolve-Path -LiteralPath $Root).Path

$tasksPath = Join-Path $rootFull "TASKS.md"

$extensions = @(".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff", ".gif", ".heic")
$dimSuffixRegex = '_\d+x\d+$'

function Get-ExifDate($img) {
    $tagOriginal = 0x9003
    $tagDigitized = 0x9004
    foreach ($tag in @($tagOriginal, $tagDigitized)) {
        try {
            $pi = $img.GetPropertyItem($tag)
            if ($pi -and $pi.Value) {
                $raw = [System.Text.Encoding]::ASCII.GetString($pi.Value)
                $raw = $raw.Trim([char]0)
                if ($raw) {
                    return [datetime]::ParseExact($raw, 'yyyy:MM:dd HH:mm:ss', $null)
                }
            }
        } catch { }
    }
    return $null
}

function Get-DimensionsAndDate($path) {
    $result = [ordered]@{ Width = $null; Height = $null; Date = $null }
    try {
        $img = [System.Drawing.Image]::FromFile($path)
        try {
            $result.Width = $img.Width
            $result.Height = $img.Height
            $result.Date = Get-ExifDate $img
        } finally {
            $img.Dispose()
        }
    } catch { }
    return $result
}

function Get-UniquePath($folder, $fileName) {
    $candidate = Join-Path $folder $fileName
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    $base = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $ext = [System.IO.Path]::GetExtension($fileName)
    $i = 1
    while ($true) {
        $name = "{0}_dup{1}{2}" -f $base, $i, $ext
        $candidate = Join-Path $folder $name
        if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
        $i++
    }
}

Add-Content -Path $tasksPath -Value ("`n## Script Run " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Add-Content -Path $tasksPath -Value ("Script: " + (Split-Path -Leaf $PSCommandPath))
Add-Content -Path $tasksPath -Value ("Root: " + $rootFull)
Add-Content -Path $tasksPath -Value ("Subfolders: " + ($Subfolders -join ', '))

$processed = 0
$skippedDim = 0
$movedUndetermined = 0
$lastPath = $null

foreach ($sub in $Subfolders) {
    $subPath = Join-Path $rootFull $sub
    if (-not (Test-Path -LiteralPath $subPath)) { continue }
    $dir = Get-Item -LiteralPath $subPath
    if (-not $dir.PSIsContainer) { continue }

    Get-ChildItem -LiteralPath $subPath -Recurse -File | Where-Object {
        $extensions -contains $_.Extension.ToLower()
    } | ForEach-Object {
        $file = $_
        if ($lastPath -eq $file.FullName) {
            Add-Content -Path $tasksPath -Value ("Loop detected at: " + $file.FullName)
            return
        }
        $lastPath = $file.FullName

        $info = Get-DimensionsAndDate $file.FullName
        if (-not $info.Width -or -not $info.Height) {
            $skippedDim++
            Add-Content -Path $tasksPath -Value ("Skipped (no dimensions): " + $file.FullName)
            return
        }

        $base = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $ext = $file.Extension
        $hasSuffix = $base -match $dimSuffixRegex
        if (-not $hasSuffix) {
            $newName = "{0}_{1}x{2}{3}" -f $base, $info.Width, $info.Height, $ext
            $newPath = Join-Path $file.Directory.FullName $newName
            if ($newPath -ne $file.FullName -and $PSCmdlet.ShouldProcess($file.FullName, "Rename to add dimension suffix ($newName)")) {
                Rename-Item -LiteralPath $file.FullName -NewName $newName
                $file = Get-Item -LiteralPath $newPath
            }
        }

        # Prefer LastWriteTime over CreationTime as the fallback: CreationTime resets to "now"
        # on many copy/import operations (the exact scenario this script sorts), while
        # LastWriteTime is more often preserved from the source.
        $year = if ($info.Date) { $info.Date.Year } else { $file.LastWriteTime.Year }

        $destFolder = if ($year) { Join-Path $rootFull $year } else { Join-Path $rootFull "Undetermined" }
        if (-not (Test-Path -LiteralPath $destFolder)) {
            New-Item -ItemType Directory -Path $destFolder | Out-Null
        }
        if (-not $year) { $movedUndetermined++ }

        $destPath = Get-UniquePath $destFolder $file.Name
        if ($destPath -ne $file.FullName -and $PSCmdlet.ShouldProcess($file.FullName, "Move to $destPath")) {
            Move-Item -LiteralPath $file.FullName -Destination $destPath
            Add-Content -Path $tasksPath -Value ("Processed: " + $destPath)
            $processed++
        }
    }
}

Add-Content -Path $tasksPath -Value ("Summary: processed=" + $processed + ", skipped_no_dimensions=" + $skippedDim + ", moved_undetermined=" + $movedUndetermined)
Write-Host "Processed: $processed, Skipped (no dimensions): $skippedDim, Moved to Undetermined: $movedUndetermined"
