<#
.SYNOPSIS
    Creates a directory junction that's resilient to drive-letter reassignment, using Volume GUIDs.

.DESCRIPTION
    Resolves -TargetPath (a standard drive-letter path) into its absolute Volume GUID equivalent
    and creates a directory junction at -LinkPath pointing at it. This decouples the link from
    volatile drive letter assignments (useful for e.g. linking back to a dotfiles directory on
    a drive whose letter can change) and bypasses New-Item's parsing limitations with Win32
    device namespace paths by invoking `cmd.exe /c mklink /J` directly.

    Does nothing if -LinkPath already exists (won't overwrite an existing link or file).

.PARAMETER TargetPath
    The real directory to link to. Required.

.PARAMETER LinkPath
    Where to create the junction. Required. Fails without changes if this path already exists.

.EXAMPLE
    .\New-ResilientJunction.ps1 -TargetPath "E:\dotfiles" -LinkPath "$env:USERPROFILE\dotfiles"
    Creates a junction at %USERPROFILE%\dotfiles pointing at E:\dotfiles via its Volume GUID.

.EXAMPLE
    .\New-ResilientJunction.ps1 -TargetPath "E:\dotfiles" -LinkPath "$env:USERPROFILE\dotfiles" -WhatIf
    Previews the junction that would be created, without creating it.

.NOTES
    Prerequisites: Windows with NTFS volumes.
    Platform: Windows-only - NTFS directory junctions and Volume GUID paths have no
    cross-platform equivalent. Symlinks (New-Item -ItemType SymbolicLink) are the portable
    alternative when drive-letter resilience isn't required.
#>

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetPath,

    [Parameter(Mandatory = $false)]
    [string]$LinkPath,

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

if (-not $TargetPath) {
    Write-Error "TargetPath is required. Run with -Help for usage."
    exit 1
}
if (-not $LinkPath) {
    Write-Error "LinkPath is required. Run with -Help for usage."
    exit 1
}

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

function New-JunctionFromGuidPath {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LinkPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VolumeGuidPath
    )

    if (Test-Path -Path $LinkPath) {
        Write-Warning "Target link path already exists at: $LinkPath"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($LinkPath, "Create junction to $VolumeGuidPath")) {
        return
    }

    try {
        # Bypass New-Item: invoke native cmd.exe to handle the Win32 namespace correctly.
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

Write-Host "Initializing resilient link creation..." -ForegroundColor Cyan

$guidPath = Get-VolumeGuidPath -Path $TargetPath

if ($guidPath) {
    Write-Host "Resolved GUID Path: " -ForegroundColor Cyan -NoNewline
    Write-Host $guidPath

    New-JunctionFromGuidPath -LinkPath $LinkPath -VolumeGuidPath $guidPath
} else {
    Write-Warning "Execution aborted due to path resolution failure."
}
