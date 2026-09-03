<#
.SYNOPSIS
    TODO: One line describing what this script does.

.DESCRIPTION
    TODO: Full description - what it does, its defaults, and any side effects (files written,
    things deleted/moved, network calls, external tools invoked, etc).

.PARAMETER Path
    TODO: One .PARAMETER block per parameter. Delete this one if you don't need a path parameter.
    Defaults to the current working directory - see .ai/CONVENTIONS.md section 6.

.PARAMETER Force
    TODO: If this script mutates or deletes anything, give it a non-interactive bypass switch
    (Force/Yes/NonInteractive - pick whichever name fits) so it can run unattended. Delete this
    block if the script doesn't need one.

.EXAMPLE
    .\Verb-Noun.ps1
    TODO: Describe what the minimal invocation does.

.EXAMPLE
    .\Verb-Noun.ps1 -Path "C:\Somewhere" -Force
    TODO: Describe a more realistic invocation.

.NOTES
    Prerequisites: TODO - e.g. PowerShell 7+, ImageMagick v7+, Python 3.
    Platform: Cross-platform | Windows-only (<reason - see .ai/CONVENTIONS.md section 5>)
#>

# Remove SupportsShouldProcess if this script never deletes/overwrites/mutates anything.
# Keep PositionalBinding = $false: without it, a bare "--help" silently binds positionally to
# the first untyped string parameter (e.g. -Path) instead of falling through to the help check
# below - confirmed by testing. Only give a parameter an explicit Position if you deliberately
# want positional use (e.g. `.\Verb-Noun.ps1 "C:\file.txt"`).
[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    # TODO: replace with this script's real parameters.
    # NEVER set Mandatory = $true here, even for a parameter with no sane default: PowerShell
    # validates mandatory parameters before the script body (and the help check below) ever
    # runs, so "-Help" alone would fail with "missing mandatory parameter" instead of showing
    # help - confirmed by testing. Keep Mandatory = $false and validate presence manually,
    # after the help check (see .ai/CONVENTIONS.md section 4).
    [Parameter(Mandatory = $false)]
    [string]$Path = (Get-Location).Path,

    # TODO: rename/remove to match whatever non-interactive bypass (if any) this script needs.
    [switch]$Force,

    # --- Standard help contract (.ai/CONVENTIONS.md section 4) - keep these two as-is. ---
    [Alias('h')]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true, DontShow = $true)]
    [string[]]$RemainingArguments
)

# NOTE: this path is relative to Templates/, where this file currently lives. Once you copy
# this script into PowerShell/ (or PowerShell/Windows-Only/) directly, drop the "..":
#   . (Join-Path -Path $PSScriptRoot -ChildPath "Common" -AdditionalChildPath "ScriptHelp.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath "Common", "ScriptHelp.ps1")
if (Test-HelpRequested -Help:$Help -RemainingArguments $RemainingArguments) {
    Get-Help -Full $PSCommandPath
    return
}

# --- Main logic ---
# TODO: replace this with the script's real behavior. For a mutating action, wrap it like:
#
#   if ($PSCmdlet.ShouldProcess($target, "Delete")) {
#       Remove-Item -LiteralPath $target -Force
#   }
#
throw "This is a template, not a runnable script. Copy it to a Verb-Noun.ps1 name and fill in the TODOs (see .ai/CONVENTIONS.md)."
