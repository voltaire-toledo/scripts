#Requires -Version 7.0
<#
.SYNOPSIS
  List and delete local Codex CLI session storage.

.EXAMPLES
  ./Invoke-CodexSession.ps1 list
  ./Invoke-CodexSession.ps1 delete 019e626d --dry-run
  ./Invoke-CodexSession.ps1 delete 019e626d --yes
  ./Invoke-CodexSession.ps1 clear --dry-run
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $SessionArgs
)

$ErrorActionPreference = "Stop"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
  throw "Python is required because Codex session metadata is stored partly in SQLite."
}

$script = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\Python\codex-sessions.py")

if (-not $SessionArgs -or $SessionArgs.Count -eq 0) {
  $SessionArgs = @("list")
}

& $python.Source $script.Path @SessionArgs
if ($LASTEXITCODE -ne 0) {
  throw "codex-sessions exited with code $LASTEXITCODE"
}
