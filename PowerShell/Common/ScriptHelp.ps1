<#
.SYNOPSIS
    Shared help-detection helper for the standard help contract (see .ai/CONVENTIONS.md).
.DESCRIPTION
    Dot-source this file and call Test-HelpRequested so every script's -Help/-h/--help/-help//?
    handling shares one implementation instead of each script re-deriving the match logic.
#>

function Test-HelpRequested {
    <#
    .SYNOPSIS
        Returns $true if the caller's help switch or arguments indicate help was requested.
    .DESCRIPTION
        PowerShell's parameter binder rejects a bare "--help" (it isn't a valid -Name token), so
        scripts must declare a ValueFromRemainingArguments catch-all and check it here. Matches
        -Help/-h (already bound to $Help by the caller) plus the raw tokens --help, -help, and /?
        that would otherwise fail to bind.

        If the script also has a parameter with an explicit Position (deliberately supporting
        positional invocation, e.g. ".\Verb-Noun.ps1 file.txt"), a bare "--help" will bind to
        THAT parameter instead of falling through to RemainingArguments - PowerShell resolves
        explicit positions before the catch-all. Pass that parameter's raw value via
        -PositionalValues so it's still recognized as a help request. That parameter must also be
        Mandatory = $false (a Mandatory parameter fails PowerShell's own binding check before the
        script body - and this function - ever runs, blocking -Help too); validate its presence
        manually after this check instead.
    .PARAMETER Help
        The caller's own [switch]$Help value.
    .PARAMETER RemainingArguments
        The caller's own [string[]]$RemainingArguments (ValueFromRemainingArguments) value.
    .PARAMETER PositionalValues
        Values of any explicitly-positioned parameters that could have swallowed a help token.
    .EXAMPLE
        Test-HelpRequested -Help:$Help -RemainingArguments $RemainingArguments
    .EXAMPLE
        Test-HelpRequested -Help:$Help -RemainingArguments $RemainingArguments -PositionalValues @($SourceFilePath)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [switch]$Help,

        [AllowNull()]
        [string[]]$RemainingArguments,

        [AllowNull()]
        [string[]]$PositionalValues
    )

    if ($Help) { return $true }

    $candidates = @()
    if ($RemainingArguments) { $candidates += $RemainingArguments }
    if ($PositionalValues) { $candidates += $PositionalValues }
    if (-not $candidates) { return $false }

    return [bool]($candidates | Where-Object { $_ -match '^(--help|-help|/\?)$' })
}
