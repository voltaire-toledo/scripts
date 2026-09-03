<#
.SYNOPSIS
    Recursively deletes all empty subdirectories under a root path.

.DESCRIPTION
    Finds and deletes every empty subdirectory under -Root (the root itself is never deleted).
    Processes deepest directories first so nested empty trees collapse correctly in one pass.
    Prompts for confirmation once up front unless -Force is supplied.

.PARAMETER Root
    Root path to scan. Defaults to the current working directory.

.PARAMETER Force
    Skips the upfront confirmation prompt, so this can run unattended/from another script.

.PARAMETER HideProgress
    Suppresses the per-folder "Processing.../Deleted/Not empty" console output.

.EXAMPLE
    .\Remove-EmptyFolders.ps1
    Interactively cleans empty subdirectories under the current directory.

.EXAMPLE
    .\Remove-EmptyFolders.ps1 -Root "D:\Photos" -Force
    Cleans D:\Photos without prompting.

.EXAMPLE
    .\Remove-EmptyFolders.ps1 -Root "D:\Photos" -WhatIf
    Previews which empty subdirectories would be deleted, without deleting anything.

.NOTES
    Prerequisites: None.
    Platform: Cross-platform.
#>

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $false)]
    [string]$Root = (Get-Location).Path,

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

if (-not $Force -and -not $WhatIfPreference) {
    Write-Host "WARNING: This script will delete all empty subdirectories within: $Root" -ForegroundColor Yellow
    $confirmation = Read-Host "Do you want to proceed? (Y/N)"
    if ($confirmation -notmatch '^[yY]$') {
        Write-Host "Operation cancelled by user."
        exit 0
    }
}

Set-StrictMode -Version 3.0

$rootFull = (Resolve-Path -LiteralPath $Root).Path

function Write-ProgressLog {
    param($Message, $Color, $NoNewline = $false)
    if (-not $HideProgress) {
        Write-Host $Message -ForegroundColor $Color -NoNewline:$NoNewline
    }
}

# Delete empty directories under the root (excluding the root itself); deepest first so nested
# empty trees collapse in one pass.
Get-ChildItem -LiteralPath $rootFull -Recurse -Force -Directory | Sort-Object FullName -Descending | ForEach-Object {
    $dir = $_
    Write-ProgressLog "Processing: $($dir.FullName)..." Cyan -NoNewline $true
    if ($dir.FullName -eq $rootFull) {
        Write-ProgressLog "(skipping)" Yellow
        return
    }
    $hasChildren = Get-ChildItem -LiteralPath $dir.FullName -Force | Select-Object -First 1
    if ($hasChildren) {
        Write-ProgressLog "Not empty" Yellow
        return
    }
    if ($PSCmdlet.ShouldProcess($dir.FullName, "Delete empty directory")) {
        try {
            Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction Stop
            Write-ProgressLog "Deleted" Green
        }
        catch {
            Write-ProgressLog "Skipped ($($_.Exception.Message))" Yellow
        }
    }
}
