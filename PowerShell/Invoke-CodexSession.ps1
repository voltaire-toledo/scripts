<#
.SYNOPSIS
    List and delete local Codex CLI session storage.

.DESCRIPTION
    Thin wrapper around Python/codex-sessions.py, which does the actual work: it lists and
    selectively deletes local Codex CLI session storage from CODEX_HOME or ~/.codex, removing
    the selected transcript file, session_index.jsonl row, history.jsonl rows, and matching
    SQLite metadata/log rows. Destructive operations prompt unless --yes is supplied.

    All arguments after the script name are forwarded to codex-sessions.py as-is.

.PARAMETER SessionArgs
    Arguments forwarded to codex-sessions.py: a subcommand (list/delete/clear/backup) and its
    own flags. Defaults to "list" if omitted entirely.

.EXAMPLE
    .\Invoke-CodexSession.ps1 list
    Lists local Codex sessions.

.EXAMPLE
    .\Invoke-CodexSession.ps1 delete 019e626d --dry-run
    Previews deleting a session by full ID or unambiguous prefix.

.EXAMPLE
    .\Invoke-CodexSession.ps1 delete 019e626d --yes
    Deletes a session after explicit confirmation bypass.

.EXAMPLE
    .\Invoke-CodexSession.ps1 clear --dry-run
    Previews deleting all local sessions.

.NOTES
    Prerequisites: PowerShell 7+, Python 3 (Codex stores part of its session metadata in SQLite).
    Platform: Cross-platform.
#>
#Requires -Version 7.0

[CmdletBinding(PositionalBinding = $false)]
param(
    [Alias('h')]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$SessionArgs
)

$ErrorActionPreference = "Stop"

# This wrapper forwards everything to codex-sessions.py's own argparse --help, so top-level
# -Help/-h/--help (no subcommand) shows THIS script's help; "<subcommand> --help" (e.g.
# "delete --help") is intentionally left alone so it forwards to Python for subcommand-specific
# detail - that's why this doesn't use the shared Test-HelpRequested (it matches any position,
# not just the first token).
$firstArg = $SessionArgs | Select-Object -First 1
if ($Help -or ($firstArg -and $firstArg -match '^(-h|--help|-help|/\?)$')) {
    Get-Help -Full $PSCommandPath
    return
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $python) {
    throw "Python is required because Codex session metadata is stored partly in SQLite."
}

$script = Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath "Python", "codex-sessions.py")

if (-not $SessionArgs -or $SessionArgs.Count -eq 0) {
    $SessionArgs = @("list")
}

& $python.Source $script.Path @SessionArgs
if ($LASTEXITCODE -ne 0) {
    throw "codex-sessions exited with code $LASTEXITCODE"
}
