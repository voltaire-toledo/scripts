<#
.SYNOPSIS
    Recursively finds and deletes macOS artifact files and metadata folders.

.DESCRIPTION
    Scans a directory tree and deletes common macOS metadata and shadow files left behind
    when sharing or backing up files across non-Apple filesystems (NTFS, SMB, FAT).
    Targets:
      - AppleDouble resource fork / shadow files (._*)
      - Desktop services store files (.DS_Store)
      - macOS zip extraction metadata directories (__MACOSX)
      - macOS volume metadata directories (.Spotlight-V100, .Trashes, .fseventsd)
    Prompts for confirmation once up front unless -Force is supplied.

.PARAMETER Path
    Root directory path to scan. Defaults to the current working directory.

.PARAMETER Force
    Skips the upfront confirmation prompt to allow unattended execution.

.PARAMETER HideProgress
    Suppresses the per-file progress console output.

.EXAMPLE
    .\Remove-MacOsArtifacts.ps1
    Interactively scans and cleans macOS artifacts under the current working directory.

.EXAMPLE
    .\Remove-MacOsArtifacts.ps1 -Path "D:\CODE" -Force
    Recursively deletes all macOS artifacts in D:\CODE without prompting.

.EXAMPLE
    .\Remove-MacOsArtifacts.ps1 -Path "D:\CODE" -WhatIf
    Previews which files and directories would be deleted, without making changes.

.NOTES
    Prerequisites: None.
    Platform: Cross-platform.
#>

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$HideProgress,

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

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "Path '$Path' does not exist."
    exit 1
}

$targetFull = (Resolve-Path -LiteralPath $Path).Path

if (-not $Force -and -not $WhatIfPreference) {
    Write-Host "WARNING: This script will recursively delete all macOS artifact files (._*, .DS_Store, __MACOSX, etc.) within: $targetFull" -ForegroundColor Yellow
    $confirmation = Read-Host "Do you want to proceed? (Y/N)"
    if ($confirmation -notmatch '^[yY]$') {
        Write-Host "Operation cancelled by user."
        exit 0
    }
}

Set-StrictMode -Version 3.0

function Write-ProgressLog {
    param($Message, $Color, $NoNewline = $false)
    if (-not $HideProgress) {
        Write-Host $Message -ForegroundColor $Color -NoNewline:$NoNewline
    }
}

$filesFound = 0
$fileCount = 0
$dirsFound = 0
$dirCount = 0
$bytesFreed = 0

Write-ProgressLog "Scanning for macOS artifacts in: $targetFull" Cyan

# 1. Delete macOS artifact files: ._* and .DS_Store
Get-ChildItem -LiteralPath $targetFull -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like '._*' -or $_.Name -eq '.DS_Store'
} | ForEach-Object {
    $item = $_
    $size = $item.Length
    $filesFound++
    Write-ProgressLog "Deleting file: $($item.FullName)... " DarkGray -NoNewline $true
    if ($PSCmdlet.ShouldProcess($item.FullName, "Delete macOS artifact file")) {
        try {
            Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
            $fileCount++
            $bytesFreed += $size
            Write-ProgressLog "Deleted" Green
        }
        catch {
            Write-ProgressLog "Failed ($($_.Exception.Message))" Red
        }
    }
}

# 2. Delete macOS artifact directories: __MACOSX, .Spotlight-V100, .Trashes, .fseventsd
Get-ChildItem -LiteralPath $targetFull -Recurse -Force -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -eq '__MACOSX' -or
    $_.Name -eq '.Spotlight-V100' -or
    $_.Name -eq '.Trashes' -or
    $_.Name -eq '.fseventsd'
} | Sort-Object FullName -Descending | ForEach-Object {
    $dir = $_
    $dirsFound++
    Write-ProgressLog "Deleting directory: $($dir.FullName)... " DarkGray -NoNewline $true
    if ($PSCmdlet.ShouldProcess($dir.FullName, "Delete macOS artifact directory")) {
        try {
            Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction Stop
            $dirCount++
            Write-ProgressLog "Deleted" Green
        }
        catch {
            Write-ProgressLog "Failed ($($_.Exception.Message))" Red
        }
    }
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "macOS Artifact Cleanup Complete" -ForegroundColor Green
Write-Host "  Files found        : $filesFound" -ForegroundColor White
Write-Host "  Files deleted      : $fileCount" -ForegroundColor White
Write-Host "  Directories found  : $dirsFound" -ForegroundColor White
Write-Host "  Directories deleted: $dirCount" -ForegroundColor White
Write-Host "  Space freed        : $([Math]::Round($bytesFreed / 1KB, 2)) KB ($bytesFreed bytes)" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
