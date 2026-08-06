<#
.SYNOPSIS
    Converts a single SVG or PNG file to a multi-resolution ICO file using ImageMagick.

.DESCRIPTION
    This script takes a source file path (SVG or PNG), validates it, and uses ImageMagick 
    to create an ICO file containing the following sizes: 256x256, 64x64, 48x48, 32x32, 24x24, 16x16.
    Requires ImageMagick v7+ to be installed and in the system PATH.

.PARAMETER SourceFilePath
    The path to the source SVG or PNG file.

.EXAMPLE
    .\Convert-SvgToIco.ps1 -SourceFilePath "C:\Icons\logo.svg"
    .\Convert-SvgToIco.ps1 "C:\Icons\image.png"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$SourceFilePath
)

# 1. Validate Input
if (-not (Test-Path $SourceFilePath)) {
    Write-Error "Error: File not found at '$SourceFilePath'"
    exit 1
}

# Resolve the absolute path and extension
$InputFile = (Get-Item $SourceFilePath).FullName
$Extension = [System.IO.Path]::GetExtension($InputFile).ToLower()
$ExtensionClean = $Extension.TrimStart('.')
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
$Directory = [System.IO.Path]::GetDirectoryName($InputFile)

# Construct new filename: filename_extension.ico
$OutputFile = Join-Path $Directory "$BaseName`_$ExtensionClean.ico"

Write-Host "Input File: $InputFile" -ForegroundColor Gray
Write-Host "Output ICO: $OutputFile" -ForegroundColor Cyan

# 2. Execute ImageMagick Command
try {
    if ($Extension -eq ".svg") {
        Write-Host "Mode: SVG to ICO (Auto-Resize)" -ForegroundColor Yellow
        # SVG Mode: Use '-background none' before input to ensure transparency is respected by the renderer
        magick -background none "$InputFile" -define icon:auto-resize=256,64,48,32,24,16 "$OutputFile"
    }
    elseif ($Extension -eq ".png") {
        Write-Host "Mode: PNG to ICO (Auto-Resize)" -ForegroundColor Yellow
        # PNG Mode: Use 'icon:auto-resize' for consistent multi-resolution output while maintaining alpha
        magick "$InputFile" -background none -define icon:auto-resize=256,64,48,32,24,16 "$OutputFile"
    }
    else {
        Write-Error "Unsupported file extension: $Extension. Please provide an .svg or .png file."
        exit 1
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully created the ICO file." -ForegroundColor Green
    } else {
        Write-Error "ImageMagick failed to convert the file."
    }
} catch {
    Write-Error "An error occurred. Ensure ImageMagick is installed and 'magick' is in your PATH."
    Write-Error $_.Exception.Message
}
