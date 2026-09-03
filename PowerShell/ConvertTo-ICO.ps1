<#
.SYNOPSIS
    Converts a single SVG or PNG file, or a directory of them, to multi-resolution ICO files using ImageMagick.

.DESCRIPTION
    Takes a source path (file or directory). If a directory is provided, it processes all SVG and PNG files
    in that directory (and subdirectories if -Recurse is used). It validates the input and uses ImageMagick to
    create an ICO file containing the following sizes: 256x256, 64x64, 48x48, 32x32, 24x24, 16x16.
    The output file is written to the same directory as the source file, named "<basename>_<ext>.ico".
    If the target .ico file already exists, a timestamp suffix (yyMMddHHmmss) is added to prevent overwriting.

.PARAMETER SourceFilePath
    Path to the source .svg or .png file, or a directory containing them. Positional - can be passed without the parameter name.

.PARAMETER Recurse
    If the SourceFilePath is a directory, processes all subdirectories recursively.

.EXAMPLE
    .\ConvertTo-Ico.ps1 -SourceFilePath "C:\Icons\logo.svg"
    Converts logo.svg to C:\Icons\logo_svg.ico.

.EXAMPLE
    .\ConvertTo-Ico.ps1 "C:\Icons" -Recurse
    Converts all .svg and .png files in C:\Icons and its subdirectories.

.NOTES
    Prerequisites: ImageMagick v7+ (https://imagemagick.org/), with `magick` on PATH. Pinned to
    the `magick` command specifically (not the Common/ImageMagick.ps1 resolver) because
    `icon:auto-resize` behavior isn't guaranteed identical across `convert`/legacy ImageMagick v6.
    Platform: Cross-platform (wherever ImageMagick v7+ and `magick` are installed).
#>

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    # Mandatory = $false is deliberate, not an oversight - see .ai/CONVENTIONS.md section 4
    # ("positional invocation" note) for why a Mandatory positional parameter would block -Help.
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$SourceFilePath,

    [switch]$Recurse,

    [Alias('h')]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true, DontShow = $true)]
    [string[]]$RemainingArguments
)

. (Join-Path -Path $PSScriptRoot -ChildPath "Common" -AdditionalChildPath "ScriptHelp.ps1")
if (Test-HelpRequested -Help:$Help -RemainingArguments $RemainingArguments -PositionalValues @($SourceFilePath)) {
    Get-Help -Full $PSCommandPath
    return
}

if (-not $SourceFilePath) {
    Write-Error "SourceFilePath is required. Run with -Help for usage."
    exit 1
}

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick's 'magick' command was not found on PATH. Install ImageMagick v7+ (https://imagemagick.org/)."
    exit 1
}

if (-not (Test-Path -LiteralPath $SourceFilePath)) {
    Write-Error "Path '$SourceFilePath' could not be found or does not exist."
    exit 1
}

$Item = Get-Item -LiteralPath $SourceFilePath
$FilesToProcess = @()

if ($Item -is [System.IO.DirectoryInfo]) {
    $FindArgs = @{
        LiteralPath = $SourceFilePath
        File = $true
    }
    if ($Recurse) {
        $FindArgs.Recurse = $true
    }
    $FilesToProcess = Get-ChildItem @FindArgs | Where-Object { $_.Extension.ToLower() -in @('.svg', '.png') }
    
    if ($FilesToProcess.Count -eq 0) {
        Write-Host "No .svg or .png files found in the directory." -ForegroundColor Yellow
        exit 0
    }
} else {
    $FilesToProcess = @($Item)
    if ($Item.Extension.ToLower() -notin @('.svg', '.png')) {
        Write-Error "Unsupported file extension: $($Item.Extension). Please provide an .svg or .png file."
        exit 1
    }
}

$HasErrors = $false

foreach ($File in $FilesToProcess) {
    $InputFile = $File.FullName
    $Extension = $File.Extension.ToLower()
    $ExtensionClean = $Extension.TrimStart('.')
    $BaseName = $File.BaseName
    $Directory = $File.DirectoryName

    $OutputFile = Join-Path $Directory "$BaseName`_$ExtensionClean.ico"

    if (Test-Path -LiteralPath $OutputFile) {
        $Timestamp = Get-Date -Format "yyMMddHHmmss"
        $OutputFile = Join-Path $Directory "$BaseName`_$ExtensionClean`_$Timestamp.ico"
    }

    Write-Host "Input File: $InputFile" -ForegroundColor Gray
    Write-Host "Output ICO: $OutputFile" -ForegroundColor Cyan

    if (-not $PSCmdlet.ShouldProcess($OutputFile, "Create multi-resolution ICO")) {
        continue
    }

    try {
        if ($Extension -eq '.svg') {
            Write-Host "Mode: SVG to ICO (Auto-Resize)" -ForegroundColor Yellow
            # -background none before input so transparency is respected by the SVG renderer
            magick -background none "$InputFile" -define icon:auto-resize=256,64,48,32,24,16 "$OutputFile"
        }
        else {
            Write-Host "Mode: PNG to ICO (Auto-Resize)" -ForegroundColor Yellow
            magick "$InputFile" -background none -define icon:auto-resize=256,64,48,32,24,16 "$OutputFile"
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully created the ICO file." -ForegroundColor Green
        } else {
            Write-Error "ImageMagick failed to convert '$InputFile'."
            $HasErrors = $true
        }
    } catch {
        Write-Error "An error occurred running ImageMagick on '$InputFile': $($_.Exception.Message)"
        $HasErrors = $true
    }
}

if ($HasErrors) {
    exit 1
}
