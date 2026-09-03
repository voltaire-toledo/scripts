<#
.SYNOPSIS
    Prints a table of ANSI escape codes and their rendered result, to verify terminal styling.

.DESCRIPTION
    Demonstrates normal/bold/blink text and standard/bright colors (plus combinations) using raw
    ANSI escape sequences, so you can visually confirm a terminal's font/color settings (e.g.
    Windows Terminal's "Intense text style" and "Automatically adjust lightness" options - see
    the Windows-Terminal/README.md in this folder) are behaving as expected.

.EXAMPLE
    .\Show-AnsiDemo.ps1
    Prints the ANSI code/description/result table to the console.

.EXAMPLE
    # Toggle "Intense text style" or "Automatically adjust lightness" in Windows Terminal's
    # settings, then re-run in the same tab to visually confirm the change took effect:
    .\Show-AnsiDemo.ps1

.NOTES
    Prerequisites: A terminal that supports ANSI escape sequences (Windows Terminal, most
    Linux/macOS terminals).
    Platform: Cross-platform (ANSI escape codes render the same way under pwsh on any OS) -
    filed under Windows-Terminal/ because it exists specifically to verify Windows Terminal's
    settings, not because the script itself is Windows-only.
#>

[CmdletBinding(PositionalBinding = $false)]
param(
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

$e = [char]27
$lines = @(
    "Code       | Description              | Result",
    "-----------|--------------------------|-----------------------",
    "[0m        | Normal Text              | $($e)[0mSample Text$($e)[0m",
    "[1m        | Bold                     | $($e)[1mSample Text$($e)[0m",
    "[5m        | Blink                    | $($e)[5mSample Text$($e)[0m",
    "[1;5m      | Bold + Blink             | $($e)[1;5mSample Text$($e)[0m",
    "[34m       | Standard Blue            | $($e)[34mSample Text$($e)[0m",
    "[5;34m     | Blink + Standard Blue    | $($e)[5;34mSample Text$($e)[0m",
    "[1;5;94m   | Bold + Blink + Bright    | $($e)[1;5;94mSample Text$($e)[0m"
)
foreach ($line in $lines) {
    Write-Host $line
}
