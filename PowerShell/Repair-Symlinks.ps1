<#
.SYNOPSIS
    Finds broken symlinks and junctions and repairs, deletes, or defers each one.

.DESCRIPTION
    Recursively scans a directory for reparse points (symbolic links and junctions), checks
    whether each one's target still exists, and for every broken link either:
      - prompts you interactively to [R]epair, [D]elete, or [S]kip it (default mode), or
      - auto-repairs it by searching a separate directory tree for a same-named replacement
        (-BestEffort), enforcing that a directory link only matches a directory and a file link
        only matches a file, and deferring rather than guessing if more than one match is found.

    A relative target is resolved against the link's own containing folder (how the OS actually
    resolves it), not against the current working directory.

    Repairing - whether interactive or best-effort - works by creating the replacement link
    under a temporary name first, and only removing the old broken link once the replacement was
    created successfully, so a failed repair never leaves you with neither link.

.PARAMETER Path
    Root directory to scan recursively for symlinks/junctions. Defaults to the current working
    directory.

.PARAMETER NonInteractive
    Reports every symlink/junction found (healthy and broken) and exits without prompting.
    Exits with code 1 if any broken links were found, 0 otherwise - useful for a dotfiles
    bootstrap script or CI health check. Cannot be combined with -BestEffort.

.PARAMETER BestEffort
    Instead of prompting, auto-repairs every broken link by searching -TargetPath (recursively)
    for a file or directory whose name matches the broken link's target filename and whose type
    (file vs. directory) matches the link's own type. A link is deferred if no match is found, or
    if more than one match is found (never guesses which one is right). Combine with -WhatIf to
    preview matches without relinking anything.

.PARAMETER TargetPath
    Directory to search for replacement targets when -BestEffort is specified. Required with
    -BestEffort; ignored otherwise.

.EXAMPLE
    .\Repair-Symlinks.ps1
    Scans the current directory and walks you through fixing any broken links found.

.EXAMPLE
    .\Repair-Symlinks.ps1 -Path ~/dotfiles -WhatIf
    Previews what would happen while repairing/deleting links under ~/dotfiles, without making
    any changes - you'll still be prompted so the What-If message can describe the real action.

.EXAMPLE
    .\Repair-Symlinks.ps1 -Path ~/dotfiles -NonInteractive
    Reports broken links under ~/dotfiles without prompting; exits 1 if any were found.

.EXAMPLE
    .\Repair-Symlinks.ps1 -Path ~/dotfiles -BestEffort -TargetPath D:\CODE\dotfiles -WhatIf
    Previews which broken links under ~/dotfiles would be auto-relinked to a same-named match
    found under D:\CODE\dotfiles.

.NOTES
    Prerequisites: PowerShell 7.0+ (relies on Get-ChildItem's LinkType/Target members).
    On Windows, creating a new symbolic link (Repair/BestEffort) requires Developer Mode to be
    enabled, or an elevated PowerShell session; junctions do not require elevation. No special
    privilege is needed on macOS/Linux. Junctions themselves are an NTFS/Windows-only reparse
    point type - on macOS/Linux every discovered link will be a SymbolicLink.
    Platform: Cross-platform.
#>
#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = (Get-Location).Path,

    [switch]$NonInteractive,

    [switch]$BestEffort,

    [Parameter(Mandatory = $false)]
    [string]$TargetPath,

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

if ($BestEffort -and -not $TargetPath) {
    Write-Error "-TargetPath is required when -BestEffort is specified. Run with -Help for usage."
    exit 1
}
if ($BestEffort -and $NonInteractive) {
    Write-Error "-BestEffort and -NonInteractive cannot be used together."
    exit 1
}

function Get-ReparsePointInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    Get-ChildItem -LiteralPath $RootPath -Force -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } |
        ForEach-Object {
            $target = $_.Target | Select-Object -First 1
            $containingDir = Split-Path -Path $_.FullName -Parent

            $resolvedTarget = $null
            if ($target) {
                $resolvedTarget = if ([System.IO.Path]::IsPathRooted($target)) {
                    $target
                } else {
                    [System.IO.Path]::GetFullPath((Join-Path $containingDir $target))
                }
            }

            [pscustomobject]@{
                PathFromCWD    = [System.IO.Path]::GetRelativePath($RootPath, $_.FullName)
                FullName       = $_.FullName
                LinkType       = $_.LinkType
                Target         = $target
                ResolvedTarget = $resolvedTarget
                TargetType     = if ($_.Attributes -match 'Directory') { 'Directory' } else { 'File' }
                IsBroken       = -not ($resolvedTarget -and (Test-Path -LiteralPath $resolvedTarget))
            }
        }
}

function Repair-Link {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Item,

        [Parameter(Mandatory = $true)]
        [string]$NewTarget
    )

    $linkType = if ($Item.LinkType) { $Item.LinkType } else { 'SymbolicLink' }
    $tempPath = "$($Item.FullName).relinking-tmp"
    Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    try {
        New-Item -ItemType $linkType -Path $tempPath -Target $NewTarget -ErrorAction Stop | Out-Null
        Remove-Item -LiteralPath $Item.FullName -Force
        Rename-Item -LiteralPath $tempPath -NewName (Split-Path -Leaf $Item.FullName)
        return $true
    } catch {
        Write-Warning "  Failed to repair '$($Item.PathFromCWD)': $($_.Exception.Message)"
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Resolve-BestEffortRepair {
    <#
    Searches $TargetPath for a same-named, same-type replacement and relinks to it.
    Returns 'Repaired' or 'Deferred'.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Item,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    $filename = if ($Item.Target) { Split-Path -Path $Item.Target -Leaf } else { $null }
    if (-not $filename) {
        Write-Host "  Could not determine filename from target - deferring." -ForegroundColor Yellow
        return 'Deferred'
    }

    Write-Host "  Searching for '$filename' under '$TargetPath'..."
    $found = if ($Item.TargetType -eq 'Directory') {
        @(Get-ChildItem -Path $TargetPath -Recurse -Filter $filename -Directory -ErrorAction SilentlyContinue)
    } else {
        @(Get-ChildItem -Path $TargetPath -Recurse -Filter $filename -File -ErrorAction SilentlyContinue)
    }

    if ($found.Count -eq 0) {
        Write-Host "  Could not find '$filename' under '$TargetPath' - deferring." -ForegroundColor Yellow
        return 'Deferred'
    }
    if ($found.Count -gt 1) {
        Write-Host "  Found $($found.Count) matches for '$filename' under '$TargetPath' - ambiguous, deferring." -ForegroundColor Yellow
        return 'Deferred'
    }

    $newTargetFull = $found[0].FullName
    if (-not $PSCmdlet.ShouldProcess($Item.FullName, "Repair link to point at $newTargetFull (best-effort match)")) {
        return 'Deferred'
    }
    if (Repair-Link -Item $Item -NewTarget $newTargetFull) {
        Write-Host "  Repaired -> $newTargetFull" -ForegroundColor Green
        return 'Repaired'
    }
    return 'Deferred'
}

function Resolve-InteractiveRepair {
    <#
    Prompts for [R]epair/[D]elete/[S]kip on one broken link.
    Returns 'Repaired', 'Deleted', or 'Deferred'.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Item
    )

    $choice = Read-Host "[R]epair / [D]elete / [S]kip (default: Skip)"
    switch -Regex ($choice) {
        '^[Rr]' {
            $newTarget = Read-Host "  New target path (blank to cancel)"
            if (-not $newTarget) {
                Write-Host "  Cancelled - deferring." -ForegroundColor Yellow
                return 'Deferred'
            }
            if (-not (Test-Path -LiteralPath $newTarget)) {
                Write-Warning "  '$newTarget' does not exist - deferring '$($Item.PathFromCWD)'."
                return 'Deferred'
            }

            $newTargetFull = (Resolve-Path -LiteralPath $newTarget).Path
            if (-not $PSCmdlet.ShouldProcess($Item.FullName, "Repair link to point at $newTargetFull")) {
                return 'Deferred'
            }
            if (Repair-Link -Item $Item -NewTarget $newTargetFull) {
                Write-Host "  Repaired." -ForegroundColor Green
                return 'Repaired'
            }
            return 'Deferred'
        }
        '^[Dd]' {
            if (-not $PSCmdlet.ShouldProcess($Item.FullName, "Delete broken link")) {
                return 'Deferred'
            }
            Remove-Item -LiteralPath $Item.FullName -Force
            Write-Host "  Deleted." -ForegroundColor Green
            return 'Deleted'
        }
        default {
            Write-Host "  Deferred." -ForegroundColor Yellow
            return 'Deferred'
        }
    }
}

# --- Main logic ---

try {
    $rootFull = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
} catch {
    Write-Error "Cannot resolve path '$Path': $($_.Exception.Message)"
    exit 1
}

$inventory = @(Get-ReparsePointInventory -RootPath $rootFull)
$broken = @($inventory | Where-Object IsBroken)

if ($NonInteractive) {
    if (-not $inventory) {
        Write-Host "No symlinks or junctions found under '$rootFull'."
        exit 0
    }
    $inventory | Sort-Object PathFromCWD | Format-Table PathFromCWD, LinkType, Target, IsBroken -AutoSize
    if ($broken) {
        Write-Host "`n$($broken.Count) of $($inventory.Count) link(s) are broken." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "`nAll $($inventory.Count) link(s) resolve correctly." -ForegroundColor Green
    exit 0
}

if (-not $broken) {
    Write-Host "Scanned $($inventory.Count) symlink(s)/junction(s) under '$rootFull' - none broken."
    exit 0
}

Write-Host "Found $($broken.Count) broken link(s) under '$rootFull':`n"

$repaired = 0
$deleted = 0
$deferred = 0
$deferredItems = @()

foreach ($item in $broken) {
    Write-Host "----------------------------------------"
    Write-Host "Link:    $($item.PathFromCWD)"
    Write-Host "Type:    $($item.LinkType)"
    Write-Host "Target:  $($item.Target)"
    if ($item.ResolvedTarget) {
        Write-Host "Missing: $($item.ResolvedTarget)"
    }

    $status = if ($BestEffort) {
        Resolve-BestEffortRepair -Item $item -TargetPath $TargetPath
    } else {
        Resolve-InteractiveRepair -Item $item
    }

    switch ($status) {
        'Repaired' { $repaired++ }
        'Deleted' { $deleted++ }
        default {
            $deferred++
            $deferredItems += $item.PathFromCWD
        }
    }
}

Write-Host "`n========================================"
Write-Host "Repaired: $repaired   Deleted: $deleted   Deferred: $deferred"
if ($deferredItems) {
    Write-Host "`nStill deferred:"
    $deferredItems | ForEach-Object { Write-Host "  - $_" }
}
