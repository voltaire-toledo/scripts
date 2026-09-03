# Invoke-ImageSeal.ps1

Prepares ("seals") a Windows VM before running Sysprep and capturing it as a golden template:
cleans up logs, caches, and profiles; disables update services that would otherwise phone home
from every clone; and optionally runs Sysprep as the final step. See the script's own
comment-based help (`Get-Help -Full .\Invoke-ImageSeal.ps1`) for parameters and examples - this
file covers the full task list, external tool requirements, and troubleshooting that don't fit
in a comment-help block.

## Tasks performed, in order

1. Collect a free-text manifest of changes from the administrator (skippable via `-SkipManifest`).
2. Display installed Microsoft hotfixes.
3. Update local PowerShell help files.
4. Clear all event logs (via `wevtutil`).
5. Clear IE/Edge cookies, history, and web cache.
6. Empty the downloaded Windows Update cache.
7. Remove phantom drive mappings (`HKEY_USERS\.DEFAULT\Network`).
8. Clear temp folders (`C:\Windows\Temp`, `C:\Temp`, Recent items).
9. Delete unnecessary user profiles (via DELPROF2 - see Requirements).
10. Apply Group Policy (`gpupdate /force`).
11. Uninstall the GFI agent, if present - **environment-specific**: this targets one company's
    endpoint agent by hardcoded MSI GUID (`{160301DE-306A-4ADE-8A47-BC5790AF0486}`). It's a
    silent no-op if that product isn't installed; remove this task if it's not relevant to your
    environment.
12. Disable Hibernate.
13. Reset the Terminal Services grace period - **Server OS only** (checked via
    `Win32_OperatingSystem.ProductType`). Directly edits the RDS licensing grace-period registry
    key's ACL per [Dell KB 000193714](https://www.dell.com/support/kbdoc/en-us/000193714)
    (no longer needs the external `Reset-TSGracePeriod.ps1` script the original version used).
14. Disable the Windows Update service.
15. Disable the Google Update services (`gupdate`, `gupdatem`).
16. Disable the Adobe Acrobat update service.
17. Clear Citrix UPM logs.
18. Flush the DNS cache.
19. Release the DHCP IP lease (via `ipconfig /release`).
20. Windows Defender cleanup: remove current threats and clear quarantine/scan history.
21. Remove ghost devices - **manual step**: needs `devcon.exe`, not natively scriptable; this
    task just prints a reminder.
22. Clear the print spooler.
23. Component store cleanup (`DISM /online /cleanup-image /StartComponentCleanup /ResetBase`).
24. Remove custom (non-Microsoft) scheduled tasks.
25. Remove old network connection profiles.
26. Remove unwanted Appx packages (keeps the Store and Calculator).
27. Wipe free space - **manual step**: needs SDelete, not natively scriptable; this task just
    prints a reminder.
28. Remove custom OEM branding files.
29. **Sysprep** (`/oobe /generalize /shutdown`) - always a separate, final, explicitly-confirmed
    step; never runs as part of the numbered list above no matter what parameters you pass.

## Requirements

- Run as Administrator - the script checks this itself and exits cleanly if you're not elevated.
- Windows PowerShell 5.1+ / PowerShell 7+.
- [DELPROF2.EXE](https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/) placed
  next to this script - task 9 skips itself with a warning if it's missing, rather than failing.
- Optional, for manual steps only: [devcon.exe](https://learn.microsoft.com/windows-hardware/drivers/devtest/devcon)
  (ghost device removal), [SDelete](https://learn.microsoft.com/sysinternals/downloads/sdelete)
  (free-space wipe).

## Output

- `Seal-Image-Transcript_<date_time>.log` - full console transcript of the run.
- `Seal-Image-Manifest.log` - start/end/success/error/skip entries for every task, plus the
  administrator's free-text change notes.

## Safety notes

- `-DryRun` (or `-WhatIf`) previews every task, including the Sysprep prompt, without changing
  anything - every task is gated behind `ShouldProcess`, including the ones that shell out to
  external tools (`wevtutil`, `DISM`, `MsiExec`, `DELPROF2`, `gpupdate`, `powercfg`, `Sysprep`),
  which don't understand `-WhatIf` on their own.
- Sysprep requires typing `yes` at its own prompt, every time, regardless of `-PromptAll` -
  there's no flag that makes it run unattended.
- Bugs fixed during adoption from the original script (verified empirically, not just by
  inspection): `Release-NetIPAddress` was not a real cmdlet (replaced with `ipconfig /release`);
  `Remove-MpThreat -All` is not a valid parameter (replaced with piping `Get-MpThreat` into
  `Remove-MpThreat`); Sysprep previously ran unconditionally as part of the normal task list.
