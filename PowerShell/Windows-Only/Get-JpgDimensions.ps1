<#
.SYNOPSIS
    Reports the pixel width and height of every .jpg file in the current directory.

.DESCRIPTION
    Legacy System.Drawing-based implementation, kept as a Windows-only fallback. Prefer
    PowerShell/Get-ImageDimensions.ps1 (cross-platform, ImageMagick-based) unless you
    specifically need this one and don't have ImageMagick installed.

.EXAMPLE
    cd "C:\Photos"
    .\Get-JpgDimensions.ps1
    Reports dimensions for every *.jpg in C:\Photos.

.EXAMPLE
    cd "C:\Photos"
    .\Get-JpgDimensions.ps1 | Sort-Object { [int]($_ -replace '.*Width: (\d+).*', '$1') } -Descending
    Reports dimensions, sorted from widest to narrowest.

.NOTES
    Prerequisites: .NET System.Drawing assembly (available by default on Windows).
    Platform: Windows-only - System.Drawing.Common has no supported non-Windows implementation
    in modern .NET. See PowerShell/Get-ImageDimensions.ps1 for the cross-platform equivalent.
#>

[CmdletBinding(PositionalBinding = $false)]
param(
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

Add-Type -AssemblyName System.Drawing
$jpgFiles = Get-ChildItem -Path "*.jpg"
foreach ($file in $jpgFiles) {
    $image = $null
    try {
        $image = [System.Drawing.Image]::FromFile($file.FullName)
        $width = $image.Width
        $height = $image.Height
        Write-Output "File: $($file.Name), Width: $width, Height: $height"
    }
    finally {
        if ($null -ne $image) {
            $image.Dispose()
        }
    }
}
