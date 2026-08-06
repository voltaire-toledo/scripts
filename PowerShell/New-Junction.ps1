<#
.SYNOPSIS
    Creates a highly resilient directory junction using Volume GUIDs.
    Useful for creating symlinks back to the dotfiles directory
.DESCRIPTION
    This script resolves a standard drive-letter path into its absolute 
    Volume GUID equivalent and creates a directory junction. This decouples 
    the link from volatile drive letter assignments and bypasses PowerShell's 
    New-Item parsing limitations with Win32 Device Namespace paths.
#>

# ---------------------------------------------------------
# Core Functions
# ---------------------------------------------------------

function Get-VolumeGuidPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        $driveLetter = $item.PSDrive.Name
        $driveRoot = $item.PSDrive.Root

        if (-not $driveLetter) {
            Write-Error "Could not determine drive letter for path: $Path"
            return
        }

        # Query the underlying volume for its immutable UniqueId
        $volumeId = (Get-Volume -DriveLetter $driveLetter -ErrorAction Stop).UniqueId

        # Isolate the relative structure by stripping the drive root
        $relativePath = $item.FullName.Substring($driveRoot.Length)

        # Reassemble the path using the Volume GUID
        return Join-Path -Path $volumeId -ChildPath $relativePath
    }
    catch {
        Write-Error "Failed to resolve Volume GUID path for '$Path': $_"
    }
}

function New-ResilientJunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LinkPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VolumeGuidPath
    )

    try {
        if (Test-Path -Path $LinkPath) {
            Write-Warning "Target link path already exists at: $LinkPath"
            return
        }

        # Bypass New-Item: Invoke native cmd.exe to handle the Win32 namespace correctly
        $invokeResult = & cmd.exe /c mklink /J "`"$LinkPath`"" "`"$VolumeGuidPath`"" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Success: " -ForegroundColor Green -NoNewline
            Write-Host $invokeResult
        } else {
            Write-Error "Failed to create junction. Details: $invokeResult"
        }
    }
    catch {
        Write-Error "Exception occurred during junction creation: $_"
    }
}

# ---------------------------------------------------------
# Execution Context
# ---------------------------------------------------------

# 1. Define your inputs
$TargetSsdDirectory = "E:\TargetDirectory" # Replace with your SSD's current path
$ProfileLinkPath    = Join-Path -Path $env:USERPROFILE -ChildPath "LinkedSSD"

Write-Host "Initializing resilient link creation..." -ForegroundColor Cyan

# 2. Resolve the mutable path to an immutable GUID path
$guidPath = Get-VolumeGuidPath -Path $TargetSsdDirectory

if ($guidPath) {
    Write-Host "Resolved GUID Path: " -ForegroundColor Cyan -NoNewline
    Write-Host $guidPath

    # 3. Create the junction
    New-ResilientJunction -LinkPath $ProfileLinkPath -VolumeGuidPath $guidPath
} else {
    Write-Warning "Execution aborted due to path resolution failure."
}