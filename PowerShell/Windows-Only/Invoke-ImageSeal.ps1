<#
.SYNOPSIS
    Seals a Windows system in preparation for Sysprep and deployment as a golden image template.

.DESCRIPTION
    Runs a sequence of cleanup/prep tasks against the LOCAL machine - clearing event logs,
    browser history, temp files, and update caches; deleting stale user profiles; disabling
    update services for Windows/Google/Adobe; removing scheduled tasks, network profiles, and
    unwanted Appx packages; running a DISM component-store cleanup; and more. Every task is
    logged to a transcript and a manifest log. See Invoke-ImageSeal.md (next to this script) for
    the full task list, external tool requirements, and troubleshooting notes.

    Every task - including ones that shell out to external tools like wevtutil, DISM, or
    DELPROF2 - is gated behind PowerShell's ShouldProcess, so -WhatIf/-DryRun previews the full
    run without touching the system: this script does NOT rely on native cmdlets' own -WhatIf
    support, because several tasks invoke external .exe tools that have no such support at all.

    Sysprep is never run as part of the normal task sequence, no matter what parameters are
    passed. It's a separate, final step that always requires typing "yes" at an explicit prompt
    (even when -PromptAll is off) - because generalizing and shutting down the machine is the
    one step here that can't be undone.

.PARAMETER SkipManifest
    Skips the prompts for the administrator to enter a free-text list of changes to record in
    the manifest log.

.PARAMETER PromptAll
    Prompts for confirmation before every task (except manifest collection, governed by
    -SkipManifest, and Sysprep, which always prompts regardless of this switch).

.PARAMETER DryRun
    Preview mode: shows what every task would do without changing anything on the system.
    Equivalent to passing -WhatIf; provided under this name too since that's the more familiar
    term outside PowerShell for this audience.

.EXAMPLE
    .\Invoke-ImageSeal.ps1 -DryRun
    Previews every task (including Sysprep, if you say "yes" at its prompt) with no real changes.

.EXAMPLE
    .\Invoke-ImageSeal.ps1 -SkipManifest -PromptAll
    Runs for real, skipping the free-text change log, and asking y/n before each task.

.EXAMPLE
    .\Invoke-ImageSeal.ps1
    Runs for real: collects a manifest, then runs every task without per-task prompts.

.NOTES
    Prerequisites: Windows, an elevated (Run as Administrator) PowerShell session,
    DELPROF2.EXE (https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/) placed
    next to this script for the user-profile cleanup task. Devcon and SDelete are referenced as
    manual/optional steps for ghost-device removal and free-space wiping - see
    Invoke-ImageSeal.md.
    Platform: Windows-only - Sysprep, DISM, wevtutil, Group Policy, Windows services, and Appx
    packages have no cross-platform equivalent.
#>

[CmdletBinding(SupportsShouldProcess = $true, PositionalBinding = $false)]
param(
    [switch]$SkipManifest,

    [switch]$PromptAll,

    [switch]$DryRun,

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

# Checked manually (not via #Requires -RunAsAdministrator) so -Help keeps working without
# elevation - #Requires blocks the whole script, including reaching the help check above, before
# it ever runs. See CONVENTIONS.md section 4 for the same reasoning applied to Mandatory params.
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run in an elevated (Run as Administrator) PowerShell session."
    exit 1
}

if ($DryRun) {
    $WhatIfPreference = $true
}

function Get-TimeStamp {
    Get-Date -Format yyyy-MM-dd_hh-mm-ss
}

function Write-SealLog {
    param(
        [string]$Message,
        [string]$LogFile
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp $Message" | Tee-Object -FilePath $LogFile -Append
}

function Invoke-SealTask {
    <#
    Runs one task: logs start/end, honors -PromptAll, and - critically - gates the task itself
    behind $PSCmdlet.ShouldProcess. This wraps the ENTIRE scriptblock as one unit, regardless of
    whether it calls PowerShell cmdlets or shells out to an external .exe, so -WhatIf/-DryRun
    reliably prevents every task from doing anything real.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$ActionName,
        [scriptblock]$Action
    )
    Write-Host "`n****** $ActionName ******"
    Write-SealLog "$ActionName (Start)" $script:ManifestLogFile
    $start = Get-Date
    $continue = $true

    if ($PromptAll) {
        Write-Host "Do you wish to continue with *$ActionName* (" -ForegroundColor Green -NoNewline
        Write-Host "y/n" -ForegroundColor Yellow -NoNewline
        Write-Host ")?" -ForegroundColor Green -NoNewline
        if ((Read-Host) -eq "n") {
            Write-SealLog "$ActionName (Skipped by administrator)" $script:ManifestLogFile
            $continue = $false
        }
    }

    if ($continue) {
        if ($PSCmdlet.ShouldProcess($ActionName, "Run seal task")) {
            try {
                & $Action
                Write-SealLog "$ActionName (Success)" $script:ManifestLogFile
            } catch {
                Write-SealLog "$ActionName (Error): $_" $script:ManifestLogFile
            }
        } else {
            Write-SealLog "$ActionName (Skipped - WhatIf/DryRun)" $script:ManifestLogFile
        }
    }

    $duration = [math]::Round((New-TimeSpan -Start $start -End (Get-Date)).TotalSeconds, 2)
    Write-SealLog "$ActionName (End: $duration sec.)" $script:ManifestLogFile
}

$script:TranscriptLogFile = Join-Path $PSScriptRoot ("Seal-Image-Transcript_" + (Get-TimeStamp) + ".log")
$script:ManifestLogFile = Join-Path $PSScriptRoot "Seal-Image-Manifest.log"
$sealStart = Get-Date

Clear-Host
Start-Transcript -Path $script:TranscriptLogFile | Out-Null

"================================ Begin Invoke-ImageSeal ===============================" | Out-File $script:ManifestLogFile -Append

# Collecting a manifest of changes from the administrator
if ($SkipManifest) {
    Write-SealLog "Skipping Manifest collection because of the -SkipManifest parameter." $script:ManifestLogFile
} else {
    Invoke-SealTask -ActionName "Collecting a manifest of changes from the administrator" -Action {
        $adminInput = @()
        $inputLine = ''
        Write-Host "Describe an image change in each line. Enter" -ForegroundColor Green -NoNewline
        Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
        Write-Host "in a new line to exit: " -ForegroundColor Green
        while ($inputLine -ne "[quit]") {
            if ($inputLine) {
                $adminInput += "CHANGE: " + $inputLine.Trim()
            }
            $inputLine = Read-Host
        }
        if ($adminInput.Count -gt 0) {
            $adminInput | Tee-Object $script:ManifestLogFile -Append
        }
    }
}

# Every task except Sysprep (handled separately below, always with its own confirmation).
$actions = @(
    @{ Name = 'Displaying the Installed Microsoft Hotfixes'; Action = { Get-Hotfix | Sort-Object -Property InstalledOn } }
    @{ Name = 'Updating the Microsoft PowerShell help files'; Action = { Update-Help -Force -ErrorAction SilentlyContinue } }
    @{ Name = 'Clearing All Event Logs'; Action = {
        try {
            $allLogs = & wevtutil.exe el
            foreach ($log in $allLogs) {
                try {
                    & wevtutil.exe cl "$log"
                    Write-Host -ForegroundColor Gray "Cleared log: $log"
                } catch {
                    Write-Host -ForegroundColor DarkGray "Could not clear log: $log ($_)."
                }
            }
        } catch {
            Write-Host -ForegroundColor DarkGray "Could not enumerate/clear logs with wevtutil: $_"
        }
    } }
    @{ Name = 'Clearing IE Cookies, History, etc.'; Action = {
        Remove-Item -Path "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:USERPROFILE\AppData\Local\Microsoft\Windows\History\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:USERPROFILE\AppData\Local\Microsoft\Windows\WebCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    } }
    @{ Name = 'Emptying the downloaded MS Updates Folder'; Action = { Remove-Item -Path C:\Windows\SoftwareDistribution\Download\* -Recurse -Force -ErrorAction SilentlyContinue } }
    @{ Name = 'Removing Phantom Drive Mappings'; Action = {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_Users -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Path HKU:\.DEFAULT\Network\* -Recurse -Force -ErrorAction SilentlyContinue
        Remove-PSDrive HKU -ErrorAction SilentlyContinue
    } }
    @{ Name = 'Clearing Temp Folders'; Action = {
        Remove-Item -Path C:\Windows\Temp\* -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path C:\Temp\* -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $env:APPDATA\Microsoft\Windows\Recent\* -Recurse -Force -ErrorAction SilentlyContinue
    } }
    @{ Name = 'Deleting Unnecessary User Profiles'; Action = {
        $delprof2 = Join-Path -Path $PSScriptRoot -ChildPath "DELPROF2.EXE"
        if (Test-Path -LiteralPath $delprof2) {
            & $delprof2 /Q
        } else {
            Write-Host -ForegroundColor Yellow "DELPROF2.EXE not found next to this script - skipping profile cleanup. See Invoke-ImageSeal.md."
        }
    } }
    @{ Name = 'Applying Group Policy'; Action = { Start-Process -FilePath 'gpupdate.exe' -ArgumentList '/force' -Wait -NoNewWindow } }
    @{ Name = 'Uninstalling the GFI Agent'; Action = { & MsiExec.exe /X "{160301DE-306A-4ADE-8A47-BC5790AF0486}" /PASSIVE /NORESTART } }
    @{ Name = 'Disabling Hibernate Feature'; Action = { & powercfg.exe /HIBERNATE OFF } }
    @{ Name = 'Disabling the Windows Update Service'; Action = {
        if (Get-Service -Name wuauserv -ErrorAction SilentlyContinue) {
            Stop-Service -Name wuauserv -ErrorAction SilentlyContinue
            Set-Service -Name wuauserv -StartupType Disabled
        }
    } }
    @{ Name = 'Disabling the Google Update Services'; Action = {
        foreach ($svc in 'gupdate', 'gupdatem') {
            if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
                Stop-Service -Name $svc -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled
            }
        }
    } }
    @{ Name = 'Disabling the Adobe Acrobat Update Service'; Action = {
        if (Get-Service -Name AdobeARMservice -ErrorAction SilentlyContinue) {
            Stop-Service -Name AdobeARMservice -ErrorAction SilentlyContinue
            Set-Service -Name AdobeARMservice -StartupType Disabled
        }
    } }
    @{ Name = 'Clearing out the Citrix UPM logs'; Action = {
        if (Get-Service -Name ctxProfile -ErrorAction SilentlyContinue) {
            Stop-Service -Name ctxProfile -ErrorAction SilentlyContinue
        }
        Remove-Item -Path C:\Windows\System32\LogFiles\UserProfileManager\* -Recurse -Force -ErrorAction SilentlyContinue
    } }
    @{ Name = 'Flushing DNS Cache'; Action = { Clear-DnsClientCache } }
    @{ Name = 'Releasing the IP lease'; Action = {
        # Release-NetIPAddress is not a real cmdlet (confirmed via Get-Command while adopting
        # this script) - ipconfig is the actual, working way to release a DHCP lease.
        & ipconfig.exe /release
    } }
    @{ Name = 'Windows Defender Cleanup'; Action = {
        try {
            # Remove-MpThreat has no -All switch (confirmed via Get-Command/Get-Help while
            # adopting this script - it errors "parameter cannot be found"). Piping every
            # current threat into it works regardless of exactly which parameters this
            # Defender module build exposes.
            Get-MpThreat -ErrorAction SilentlyContinue | Remove-MpThreat -ErrorAction SilentlyContinue
            Remove-Item -Path 'C:\ProgramData\Microsoft\Windows Defender\Scans\History\*' -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host -ForegroundColor Gray 'Windows Defender logs and quarantine cleared.'
        } catch {
            Write-Host -ForegroundColor DarkGray "Could not clear Defender logs/quarantine: $_"
        }
    } }
    @{ Name = 'Remove Ghost Devices'; Action = {
        Write-Host -ForegroundColor Yellow 'NOTE: Ghost device removal needs devcon.exe (not natively scriptable). Run it manually - see Invoke-ImageSeal.md.'
    } }
    @{ Name = 'Clear Print Spooler'; Action = {
        Stop-Service -Name Spooler -ErrorAction SilentlyContinue
        Remove-Item -Path 'C:\Windows\System32\spool\PRINTERS\*' -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
    } }
    @{ Name = 'Component Store Cleanup (DISM)'; Action = {
        Start-Process -FilePath 'dism.exe' -ArgumentList '/online', '/cleanup-image', '/StartComponentCleanup', '/ResetBase' -Wait -NoNewWindow
    } }
    @{ Name = 'Remove Custom Scheduled Tasks'; Action = {
        Get-ScheduledTask | Where-Object { $_.TaskName -notlike 'Microsoft*' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    } }
    @{ Name = 'Remove Old Network Profiles'; Action = {
        Get-NetConnectionProfile | Remove-NetConnectionProfile -ErrorAction SilentlyContinue
    } }
    @{ Name = 'Remove Unwanted Appx Packages'; Action = {
        Get-AppxPackage | Where-Object { $_.Name -notlike '*Microsoft.WindowsStore*' -and $_.Name -notlike '*Microsoft.WindowsCalculator*' } | Remove-AppxPackage -ErrorAction SilentlyContinue
    } }
    @{ Name = 'Wipe Free Space'; Action = {
        Write-Host -ForegroundColor Yellow 'NOTE: Free-space wiping needs SDelete (not natively scriptable). Run it manually - see Invoke-ImageSeal.md.'
    } }
    @{ Name = 'Remove Custom Branding'; Action = {
        Remove-Item -Path 'C:\Windows\System32\oem*.*' -Force -ErrorAction SilentlyContinue
    } }
)

# Special case: Resetting the TS Grace Period (Server OS only)
$winClass = Get-CimInstance -ClassName Win32_OperatingSystem
Write-Host -ForegroundColor Gray "System $($winClass.Name)"
if ($winClass.ProductType -eq 3) {
    Invoke-SealTask -ActionName "Resetting the TS Grace Period" -Action {
        # Reset the RDS Licensing Grace Period per Dell KB 000193714
        $gracePeriodKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\GracePeriod'
        $reg = Get-Item $gracePeriodKey
        $acl = $reg.GetAccessControl()
        $admin = [System.Security.Principal.NTAccount]"Administrators"
        $acl.SetOwner($admin)
        $reg.SetAccessControl($acl)
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule($admin, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
        $reg.SetAccessControl($acl)
        Get-ChildItem $gracePeriodKey | Where-Object { $_.Name -match 'L\$RTMTIMEBOMB' } | Remove-Item -Force
        Write-Host -ForegroundColor Green 'Grace period registry key deleted. Reboot the server for this to take effect.'
    }
}

foreach ($a in $actions) {
    Invoke-SealTask -ActionName $a.Name -Action $a.Action
}

# Sysprep is deliberately NOT in $actions above: it must always get its own explicit
# confirmation, regardless of -PromptAll, because generalizing + shutting down the machine is
# the one step here that can't be undone. Typing anything other than exactly "yes" skips it,
# including a Read-Host failure (e.g. a non-interactive host) - the safe default is to skip.
Write-Host "`n****** Sysprep Integration ******" -ForegroundColor Cyan
Write-Host "This is the final step: Sysprep will generalize this system and shut it down." -ForegroundColor Yellow
$sysprepConfirmed = $false
try {
    $sysprepConfirmed = (Read-Host "Type 'yes' to run Sysprep now, or anything else to skip") -eq 'yes'
} catch {
    Write-Host "Could not read a confirmation (non-interactive session?) - skipping Sysprep." -ForegroundColor Yellow
}
if ($sysprepConfirmed) {
    Invoke-SealTask -ActionName "Sysprep Integration" -Action {
        Start-Process -FilePath 'C:\Windows\System32\Sysprep\Sysprep.exe' -ArgumentList '/oobe', '/generalize', '/shutdown' -Wait
    }
} else {
    Write-SealLog "Sysprep Integration (Skipped - not confirmed)" $script:ManifestLogFile
}

Write-Host -ForegroundColor Yellow "NOTE: If the paravirtual drivers (VMware Tools) were updated, please review the network adapter settings."
Write-Host -ForegroundColor Green "Invoke-ImageSeal has completed its activities."
Write-Host -ForegroundColor Green "Please hit the [Enter] key to continue." -NoNewline
Read-Host | Out-Null
$sealEnd = Get-Date
$sealDuration = [math]::Round(($sealEnd.Subtract($sealStart)).TotalSeconds, 2)
"================================= End Invoke-ImageSeal ================================= (Total: $sealDuration sec.)" | Out-File $script:ManifestLogFile -Append
Stop-Transcript | Out-Null
