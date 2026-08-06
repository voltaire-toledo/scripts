<#
.SYNOPSIS
    Copies landscape Windows Spotlight background images to a target directory and optionally renames them.
.DESCRIPTION
    Finds and copies landscape-oriented images from the local Spotlight assets directory
    to a specified target directory, renaming them as .jpg files.
    After copying, it offers to rename the files based on their "Date Taken" metadata and dimensions.
.PARAMETER TargetDir
    The directory where the wallpapers will be copied. Defaults to the script's directory.
.PARAMETER Help
    Displays this help message.
.EXAMPLE
    .\Copy-SpotLightWallpapers.ps1
.EXAMPLE
    .\Copy-SpotLightWallpapers.ps1 -TargetDir "C:\Wallpapers"
.EXAMPLE
    .\Copy-SpotLightWallpapers.ps1 --help
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$TargetDir = (Get-Location).Path,

    [Alias("h")]
    [switch]$Help
)

if ($Help) {
    Get-Help $PSCommandPath
    return
}

function Invoke-WallpaperRename {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$DirectoryPath,
        [int]$IndexStart = 1
    )

    Write-Host "`nStarting rename process in '$DirectoryPath'..." -ForegroundColor Cyan
    
    $shell = New-Object -COMObject Shell.Application
    $folder = $shell.Namespace($DirectoryPath)

    if (-not $folder) {
        Write-Error "Could not access directory: $DirectoryPath."
        return
    }

    # Define the regex pattern for already renamed files (new format)
    $renamedPattern = "^\d{4}-\d{2}-\d{2}_\d+x\d+_\d{3}\.jpg$"

    # Find property indices
    $propIndices = @{}
    $propertiesToFind = @("Date taken", "Date acquired", "Date modified", "Width", "Height")
    for ($i = 0; $i -lt 500; $i++) {
        $header = $folder.GetDetailsOf($null, $i)
        if ($header -in $propertiesToFind) {
            $propIndices[$header] = $i
        }
        if ($propIndices.Count -eq $propertiesToFind.Count) { break }
    }

    if (-not ($propIndices.ContainsKey("Width") -and $propIndices.ContainsKey("Height"))) {
        Write-Warning "Could not find all required properties (Width, Height). Skipping rename."
        return
    }

    $files = Get-ChildItem -Path $DirectoryPath -Filter "*.jpg"
    foreach ($file in $files) {
        if ($file.Name -match $renamedPattern) { continue }

        $shellFile = $folder.ParseName($file.Name)
        $dateStr = $null
        $dateSource = $null

        if ($propIndices.ContainsKey("Date taken")) {
            $dateStr = $folder.GetDetailsOf($shellFile, $propIndices["Date taken"])
            if ($dateStr) { $dateSource = "Date taken" }
        }
        
        if (-not $dateStr -and $propIndices.ContainsKey("Date acquired")) {
            $dateStr = $folder.GetDetailsOf($shellFile, $propIndices["Date acquired"])
            if ($dateStr) { $dateSource = "Date acquired" }
        }

        if (-not $dateStr -and $propIndices.ContainsKey("Date modified")) {
            $dateStr = $folder.GetDetailsOf($shellFile, $propIndices["Date modified"])
            if ($dateStr) { $dateSource = "Date modified" }
        }
        
        $widthStr = $folder.GetDetailsOf($shellFile, $propIndices["Width"])
        $heightStr = $folder.GetDetailsOf($shellFile, $propIndices["Height"])

        if ($dateStr -and $widthStr -and $heightStr) {
            try {
                $cleanedDateStr = $dateStr.Trim() -replace '[^\w\s\d:/\\]'
                $dateValue = [datetime]::Parse($cleanedDateStr, [System.Globalization.CultureInfo]::CurrentCulture)
                $width = $widthStr -replace '\D'
                $height = $heightStr -replace '\D'
                
                $index = $IndexStart
                do {
                    $newName = "{0:yyyy-MM-dd}_{1}x{2}_{3:D3}.jpg" -f $dateValue, $width, $height, $index
                    $newFilePath = Join-Path -Path $DirectoryPath -ChildPath $newName
                    $index++
                } while (Test-Path -Path $newFilePath)

                if ($PSCmdlet.ShouldProcess($file.Name, "Rename to $newName (using $dateSource)")) {
                    Rename-Item -Path $file.FullName -NewName $newName -ErrorAction Stop
                }
            }
            catch {
                Write-Warning "Could not process file $($file.Name). Error: $($_.Exception.Message)"
            }
        }
    }
}

# --- Script Configuration ---
$source = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets"
$destination = $TargetDir

# Ensure destination exists
if (-not (Test-Path -Path $destination)) {
    try {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
    }
    catch {
        Write-Host "ERROR: Could not create target directory: $destination" -ForegroundColor Red
        pause
        exit
    }
}

# --- Pre-run Checks ---
try {
    Add-Type -AssemblyName System.Drawing
}
catch {
    Write-Host "FATAL: Could not load the required System.Drawing assembly." -ForegroundColor Red
    Write-Host $_.Exception.Message
    pause
    exit
}

if (-not (Test-Path -Path $source)) {
    Write-Host "ERROR: Windows Spotlight assets folder not found at the expected location." -ForegroundColor Red
    pause
    exit
}


# --- Main Logic ---
$images = Get-ChildItem -Path $source
foreach ($img in $images) {
    try {
        $temp = Join-Path $env:TEMP ($img.Name + ".jpg")
        Copy-Item $img.FullName $temp -Force -ErrorAction Stop

        $imageObject = [System.Drawing.Image]::FromFile($temp)
        $isLandscape = $imageObject.Width -gt $imageObject.Height
        $imageObject.Dispose()

        if ($isLandscape) {
            $destFile = Join-Path $destination ($img.Name + ".jpg")
            Move-Item -Path $temp -Destination $destFile -Force
            Write-Host "Copied: $destFile"
        }
        else {
            Remove-Item $temp -Force
        }
    }
    catch {
        Write-Host "An error occurred while processing file: $($img.Name)" -ForegroundColor Red
        Write-Host "DETAILS: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nCopy process finished."

# --- Post-run Prompt ---
$confirmation = Read-Host "Do you wish to rename the copied files in '$destination' using the integrated Date-Taken logic? (y/n)"
if ($confirmation -match '^y') {
    Invoke-WallpaperRename -DirectoryPath $destination
}

Write-Host "`nScript finished. Press Enter to exit."
pause
