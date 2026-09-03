@{
    # PSUseApprovedVerbs is intentionally NOT excluded - every script here uses an approved verb
    # (see .ai/CONVENTIONS.md section 2). Verify with: Invoke-ScriptAnalyzer -Path . -Recurse -IncludeRule PSUseApprovedVerbs

    ExcludeRules = @(
        # These are interactive CLI tools meant to be run directly at a console, not modules
        # whose output is consumed by other scripts - colored, host-only status messages
        # (Write-Host -ForegroundColor ...) are the right tool here, not a style mistake.
        'PSAvoidUsingWriteHost'
    )
}
