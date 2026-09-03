<#
.SYNOPSIS
    Convenience wrapper for Sync-GitRepository.ps1 to update the current Git repository.

.DESCRIPTION
    Forwards all parameters directly to Sync-GitRepository.ps1 to pull latest main
    from origin and interactively clean up orphaned local branches.

.PARAMETER Path
    Target repository path. Defaults to current working directory.

.PARAMETER MainBranch
    Name of the main branch to pull. Auto-detected if omitted.

.PARAMETER Remote
    Remote name. Defaults to 'origin'.

.PARAMETER Force
    Deletes all identified orphaned branches without interactive prompts. (Alias: -Yes).

.PARAMETER NonInteractive
    Audits and lists orphaned branches without prompting.

.EXAMPLE
    .\Update-Repo.ps1
    Updates the current repository, prompting to delete any orphaned local branches.

.EXAMPLE
    .\Update-Repo.ps1 -Force
    Updates the current repository and deletes all orphaned local branches without prompting.

.NOTES
    Prerequisites: PowerShell 7+, Git CLI.
    Platform: Cross-platform.
#>
#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$MainBranch,

    [Parameter(Mandatory = $false)]
    [string]$Remote = 'origin',

    [Alias('Yes')]
    [switch]$Force,

    [switch]$NonInteractive,

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

$targetScript = Join-Path -Path $PSScriptRoot -ChildPath "Sync-GitRepository.ps1"
& $targetScript @PSBoundParameters
