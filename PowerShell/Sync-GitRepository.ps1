<#
.SYNOPSIS
    Pulls the latest main branch from origin and interactively deletes orphaned local branches.

.DESCRIPTION
    Streamlines the common post-PR merge workflow in a Git repository:
      1. Verifies the current working directory is inside a Git repository.
      2. Switches to the default/main branch (auto-detecting 'main' or 'master', or custom).
      3. Fetches and prunes remote tracking branches from the remote (defaults to 'origin').
      4. Pulls the latest commits into the main branch.
      5. Scans for orphaned local branches:
         - Branches whose remote tracking upstream is gone ([gone]).
         - Branches already merged into the main branch.
      6. Interactively prompts to delete each orphaned branch one-by-one, with support for
         [Y]es, [N]o, [A]ll, and [Q]uit.

    Supports -Force / -Yes to delete all orphaned branches non-interactively, -NonInteractive
    to audit and report without making changes, and -WhatIf / -Confirm for safety previews.

.PARAMETER Path
    Path to the Git repository root or any subfolder within it. Defaults to the current
    working directory.

.PARAMETER MainBranch
    Name of the primary branch to switch to and pull. If omitted, auto-detects from remote HEAD,
    or falls back to 'main' or 'master'.

.PARAMETER Remote
    Name of the remote to fetch, prune, and pull from. Defaults to 'origin'.

.PARAMETER Force
    Deletes all identified orphaned branches without interactive prompting. (Alias: -Yes).

.PARAMETER NonInteractive
    Audits and lists orphaned branches without prompting or deleting anything. Exits with code 1
    if orphans exist, 0 if clean. Useful for CI or automation.

.EXAMPLE
    .\Sync-GitRepository.ps1
    Switches to main, pulls latest origin/main, and prompts to delete any orphaned local branches.

.EXAMPLE
    .\Sync-GitRepository.ps1 -Force
    Refreshes main and automatically deletes all orphaned local branches without prompting.

.EXAMPLE
    .\Sync-GitRepository.ps1 -Path "D:\CODE\MyRepo" -WhatIf
    Previews repository updates and branch deletions without making actual changes.

.NOTES
    Prerequisites: PowerShell 7+, Git CLI available on PATH.
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

    # --- Standard help contract (.ai/CONVENTIONS.md section 4) ---
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

# --- Validate repository ---

$resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
$insideWorkTree = git -C $resolvedPath rev-parse --is-inside-work-tree 2>$null

if ($LASTEXITCODE -ne 0 -or $insideWorkTree -ne 'true') {
    Write-Error "'$resolvedPath' is not inside a valid Git repository."
    exit 1
}

$repoRoot = (git -C $resolvedPath rev-parse --show-toplevel).Trim()

# --- Determine Main Branch ---

$targetMain = $MainBranch
if (-not $targetMain) {
    # 1. Try remote HEAD reference (e.g., refs/remotes/origin/HEAD -> origin/main)
    $remoteHead = (git -C $repoRoot symbolic-ref --short "refs/remotes/$Remote/HEAD" 2>$null)
    if ($remoteHead -and $remoteHead.StartsWith("$Remote/")) {
        $targetMain = $remoteHead.Substring($Remote.Length + 1)
    }

    # 2. Check local 'main' branch
    if (-not $targetMain -and (git -C $repoRoot rev-parse --verify --quiet refs/heads/main)) {
        $targetMain = 'main'
    }

    # 3. Check local 'master' branch
    if (-not $targetMain -and (git -C $repoRoot rev-parse --verify --quiet refs/heads/master)) {
        $targetMain = 'master'
    }

    # 4. Fallback default
    if (-not $targetMain) {
        $targetMain = 'main'
    }
}

Write-Host "Repository:  $repoRoot" -ForegroundColor Cyan
Write-Host "Main Branch: $targetMain" -ForegroundColor Cyan
Write-Host "Remote:      $Remote`n" -ForegroundColor Cyan

# --- Check Working Directory State ---

$dirtyFiles = git -C $repoRoot status --porcelain
if ($dirtyFiles) {
    Write-Warning "Working tree has uncommitted or untracked changes."
}

# --- Switch to Main Branch ---

$currentBranch = (git -C $repoRoot branch --show-current).Trim()
if ($currentBranch -ne $targetMain) {
    Write-Host "Switching branch: '$currentBranch' -> '$targetMain'..." -ForegroundColor Yellow
    if ($PSCmdlet.ShouldProcess("Repository '$repoRoot'", "Switch branch from '$currentBranch' to '$targetMain'")) {
        git -C $repoRoot checkout $targetMain
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to checkout branch '$targetMain'. Aborting sync."
            exit 1
        }
    }
}

# --- Fetch & Prune Remote ---

Write-Host "Fetching and pruning remote '$Remote'..." -ForegroundColor Cyan
git -C $repoRoot fetch --prune $Remote

# --- Pull Latest Commits ---

Write-Host "Pulling latest '$targetMain' from '$Remote'..." -ForegroundColor Cyan
if ($PSCmdlet.ShouldProcess("Branch '$targetMain'", "Pull latest changes from '$Remote/$targetMain'")) {
    git -C $repoRoot pull $Remote $targetMain
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Pull encountered warnings or merge requirements. Review git output above."
    }
}

# --- Identify Orphan Local Branches ---

# 1. Get branches whose upstream remote is gone ([gone])
$branchVv = git -C $repoRoot branch -vv --no-color
$goneBranches = @{}

foreach ($line in $branchVv) {
    if ($line -match '^\*?\s+(\S+)\s+[0-9a-f]+\s+\[[^\]]*: gone\]') {
        $bName = $Matches[1]
        if ($bName -ne $targetMain -and $bName -ne 'master') {
            $goneBranches[$bName] = 'Remote tracking branch deleted [gone]'
        }
    }
}

# 2. Get branches fully merged into target main
$mergedLines = git -C $repoRoot branch --merged $targetMain --no-color
$mergedBranches = @{}

foreach ($line in $mergedLines) {
    $bName = $line.Trim().TrimStart('*').Trim()
    if ($bName -and $bName -ne $targetMain -and $bName -ne 'master' -and -not $bName.StartsWith('(')) {
        $mergedBranches[$bName] = "Merged into '$targetMain'"
    }
}

# Combine and deduplicate
$allOrphanNames = ($goneBranches.Keys + $mergedBranches.Keys) | Select-Object -Unique | Sort-Object

$orphanList = @()
foreach ($name in $allOrphanNames) {
    $reasons = @()
    if ($goneBranches.ContainsKey($name)) { $reasons += $goneBranches[$name] }
    if ($mergedBranches.ContainsKey($name) -and -not $goneBranches.ContainsKey($name)) { $reasons += $mergedBranches[$name] }

    $commitInfo = (git -C $repoRoot log -1 --format="%cr|%s" refs/heads/$name 2>$null)
    $relDate = "Unknown"
    $subject = "No commit message"
    if ($commitInfo -match '^([^|]+)\|(.*)$') {
        $relDate = $Matches[1]
        $subject = $Matches[2]
    }

    $orphanList += [pscustomobject]@{
        BranchName   = $name
        Reason       = ($reasons -join ', ')
        LastActivity = $relDate
        LastCommit   = $subject
    }
}

# --- Handle Orphan Branch Cleanup ---

if (-not $orphanList) {
    Write-Host "`nNo orphaned local branches found. Repository is up to date and clean!" -ForegroundColor Green
    exit 0
}

Write-Host "`nFound $($orphanList.Count) orphaned local branch(es):`n" -ForegroundColor Yellow

if ($NonInteractive) {
    $orphanList | Format-Table BranchName, Reason, LastActivity, LastCommit -AutoSize
    Write-Host "$($orphanList.Count) orphaned branch(es) detected." -ForegroundColor Yellow
    exit 1
}

$deletedCount = 0
$skippedCount = 0
$autoDeleteRemaining = [bool]$Force

foreach ($orphan in $orphanList) {
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "Branch:      $($orphan.BranchName)" -ForegroundColor White
    Write-Host "Reason:      $($orphan.Reason)" -ForegroundColor Yellow
    Write-Host "Last Activity: $($orphan.LastActivity) - $($orphan.LastCommit)" -ForegroundColor Gray

    $shouldDelete = $false

    if ($autoDeleteRemaining) {
        $shouldDelete = $true
    } else {
        $choice = Read-Host "Delete branch '$($orphan.BranchName)'? [Y]es / [N]o / [A]ll / [Q]uit (default: No)"
        switch -Regex ($choice) {
            '^[Yy]$' {
                $shouldDelete = $true
            }
            '^[Aa]$' {
                $autoDeleteRemaining = $true
                $shouldDelete = $true
            }
            '^[Qq]$' {
                Write-Host "Aborting remaining branch deletion prompt." -ForegroundColor Yellow
                break
            }
            default {
                Write-Host "  Skipped." -ForegroundColor DarkCyan
                $skippedCount++
            }
        }
    }

    if ($shouldDelete) {
        if ($PSCmdlet.ShouldProcess("Branch '$($orphan.BranchName)'", "Delete local branch")) {
            $delOutput = git -C $repoRoot branch -D $orphan.BranchName 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Deleted branch '$($orphan.BranchName)'." -ForegroundColor Green
                $deletedCount++
            } else {
                Write-Warning "  Failed to delete branch '$($orphan.BranchName)': $delOutput"
                $skippedCount++
            }
        } else {
            $skippedCount++
        }
    }
}

Write-Host "`n========================================" -ForegroundColor DarkGray
Write-Host "Sync Complete: Deleted $deletedCount branch(es), Skipped $skippedCount branch(es)." -ForegroundColor Green
