<#
.SYNOPSIS
    Finds folders with custom icons and reports their paths and icon locations.

.DESCRIPTION
    Recursively searches a directory for hidden desktop.ini files, which Windows Explorer uses
    to store folder customizations including custom icons. Parses each one to extract its
    IconResource or IconFile path (stripping the trailing icon index, e.g. ",0", if present).

.PARAMETER SearchPath
    The directory to start searching from. Defaults to the current user's profile directory
    (not the current working directory - custom folder icons are most usefully searched for
    across a whole profile, not wherever the shell happens to be).

.EXAMPLE
    .\Find-CustomFolderIcons.ps1
    Scans the current user's profile directory for custom folder icons.

.EXAMPLE
    .\Find-CustomFolderIcons.ps1 -SearchPath "C:\Users\Jigs\Documents"
    Scans just the Documents folder.

.NOTES
    Prerequisites: None beyond Windows itself.
    Platform: Windows-only - desktop.ini-based folder customization (IconResource/IconFile) is
    a Windows Explorer-specific mechanism with no cross-platform equivalent.
#>

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$SearchPath = $env:USERPROFILE,

    [Alias('h')]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true, DontShow = $true)]
    [string[]]$RemainingArguments
)

. (Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath "Common", "ScriptHelp.ps1")
if (Test-HelpRequested -Help:$Help -RemainingArguments $RemainingArguments -PositionalValues @($SearchPath)) {
    Get-Help -Full $PSCommandPath
    return
}

Write-Host "Scanning for custom folder icons in: $SearchPath"
Write-Host "This might take a moment depending on the number of files..." -ForegroundColor Yellow

$results = @()

# desktop.ini files are hidden/system files, so -Force is needed to see them.
Get-ChildItem -Path $SearchPath -Filter "desktop.ini" -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $folderPath = $_.DirectoryName
    $content = Get-Content $_.FullName -ErrorAction SilentlyContinue

    $iconPath = $null

    if ($content) {
        foreach ($line in $content) {
            # Check for IconResource or IconFile lines which define the custom icon
            if ($line -match '^\s*(IconResource|IconFile)\s*=\s*(.+)$') {
                $rawPath = $matches[2]

                # IconResource often contains a comma followed by an icon index (e.g., path\to\icon.ico,0)
                # We strip out the index to just get the file path
                if ($rawPath -match '^(.*),\s*-?\d+$') {
                    $iconPath = $matches[1]
                } else {
                    $iconPath = $rawPath
                }
                break
            }
        }
    }

    if ($iconPath) {
        $results += [PSCustomObject]@{
            Folder   = $folderPath
            IconPath = $iconPath
        }
    }
}

if ($results.Count -gt 0) {
    $results | Format-Table -AutoSize
    Write-Host "Found $($results.Count) folders with custom icons." -ForegroundColor Green
} else {
    Write-Host "No folders with custom icons found in $SearchPath." -ForegroundColor Yellow
}
