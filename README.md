# VT-Scripts-Library

A personal library of standalone utility scripts - image processing, file/symlink maintenance,
icon conversion, and Codex CLI session management. Every script here is meant to be run
directly, on its own, without installing this repo as a package.

See [.ai/CONVENTIONS.md](.ai/CONVENTIONS.md) for the naming, help-output, and cross-platform
rules every script follows - new scripts should be copied from a `Templates/` skeleton and built
to the same standard. `CLAUDE.md` at the repo root just points Claude Code at that file.

---

## Folder structure

```
VT-Scripts-Library/
├── CLAUDE.md                - points Claude Code at .ai/CONVENTIONS.md (gitignored - local only)
├── README.md                 - this file
├── .ai/                        - gitignored - local-only conventions
│   └── CONVENTIONS.md            - naming / help / cross-platform rules for every script
├── _TRIAGE/                     - gitignored - drop pre-existing scripts here for the
│                                   adopt-script skill
├── PowerShell/
│   ├── README.md             - PowerShell script index
│   ├── Common/                 - shared, dot-sourced helpers (not run directly)
│   ├── Templates/                - copy-from-this skeleton for a new PowerShell script
│   ├── Windows-Only/               - scripts with no cross-platform equivalent
│   └── Windows-Terminal/             - Windows Terminal config notes + verification script
├── Bash/
│   ├── README.md              - Bash script index
│   └── remove-macos-artifacts.sh - Cross-platform macOS artifact cleaner
└── Python/
    ├── README.md              - Python script index
    └── Templates/               - copy-from-this skeleton for a new Python script
```

---

## Scripts

Grouped by what each script is *for*, not by language or platform - those are secondary
attributes shown per script below. Click a script to expand its summary; full parameter tables,
every example, and prerequisites live in that language's own README (linked at the end of each
entry and all together at the bottom of this section).

### Image & Media

<details>
<summary><code>ConvertTo-Ico.ps1</code> - Converts a single SVG/PNG into a multi-resolution <code>.ico</code>.</summary>

PowerShell · Cross-platform · ImageMagick v7+
Full docs: [PowerShell/README.md](PowerShell/README.md#convertto-icops1)
</details>

<details>
<summary><code>Get-ImageDimensions.ps1</code> - Reports image width/height/EXIF date for files in a directory.</summary>

PowerShell · Cross-platform · ImageMagick
Full docs: [PowerShell/README.md](PowerShell/README.md#get-imagedimensionsps1)
</details>

<details>
<summary><code>Group-ImageFilesByYear.ps1</code> - Groups images into <code>&lt;Year&gt;</code> subfolders by EXIF/file date; adds dimension suffix.</summary>

PowerShell · Cross-platform · ImageMagick
Full docs: [PowerShell/README.md](PowerShell/README.md#group-imagefilesbyyearps1)
</details>

<details>
<summary><code>Windows-Only/Get-JpgDimensions.ps1</code> - Legacy <code>System.Drawing</code> fallback for <code>Get-ImageDimensions.ps1</code>.</summary>

PowerShell · Windows-only · `System.Drawing`
Full docs: [PowerShell/Windows-Only/README.md](PowerShell/Windows-Only/README.md#get-jpgdimensionsps1)
</details>

<details>
<summary><code>Windows-Only/Group-ImageFilesByYear.ps1</code> - Legacy <code>System.Drawing</code> fallback for <code>Group-ImageFilesByYear.ps1</code>.</summary>

PowerShell · Windows-only · `System.Drawing`
Full docs: [PowerShell/Windows-Only/README.md](PowerShell/Windows-Only/README.md#group-imagefilesbyyearps1)
</details>

<details>
<summary><code>Windows-Only/Copy-SpotlightWallpapers.ps1</code> - Copies landscape Windows Spotlight wallpapers to a target directory.</summary>

PowerShell · Windows-only · `System.Drawing`
Full docs: [PowerShell/Windows-Only/README.md](PowerShell/Windows-Only/README.md#copy-spotlightwallpapersps1)
</details>

<details>
<summary><code>Windows-Only/Rename-JpgOnDateTaken.ps1</code> - Renames JPGs to <code>yyyy-MM-dd_WIDTHxHEIGHT_###.jpg</code> by Date Taken/Acquired/Modified.</summary>

PowerShell · Windows-only · Shell COM
Full docs: [PowerShell/Windows-Only/README.md](PowerShell/Windows-Only/README.md#rename-jpgondatetakenps1)
</details>

### Filesystem & Symlink Maintenance

<details>
<summary><code>Repair-Symlinks.ps1</code> - Finds broken symlinks/junctions; repairs (interactively or best-effort), deletes, or defers each one.</summary>

PowerShell · Cross-platform · PowerShell 7+
Full docs: [PowerShell/README.md](PowerShell/README.md#repair-symlinksps1)
</details>

<details>
<summary><code>Remove-EmptyFolders.ps1</code> - Recursively deletes empty subdirectories under a root.</summary>

PowerShell · Cross-platform
Full docs: [PowerShell/README.md](PowerShell/README.md#remove-emptyfoldersps1)
</details>

<details>
<summary><code>Remove-MacOsArtifacts.ps1</code> / <code>remove-macos-artifacts.sh</code> - Recursively deletes macOS metadata (<code>._*</code>, <code>.DS_Store</code>, <code>__MACOSX</code>, etc.).</summary>

PowerShell (Cross-platform, PowerShell 7+) and Bash (Cross-platform, Bash 4+/find) versions of the same tool.
Full docs: [PowerShell/README.md](PowerShell/README.md#remove-macosartifactsps1) · [Bash/README.md](Bash/README.md#remove-macos-artifactssh)
</details>

<details>
<summary><code>Windows-Only/New-ResilientJunction.ps1</code> - Creates a directory junction resilient to drive-letter reassignment, via Volume GUID.</summary>

PowerShell · Windows-only · NTFS
Full docs: [PowerShell/Windows-Only/README.md](PowerShell/Windows-Only/README.md#new-resilientjunctionps1)
</details>

<details>
<summary><code>Windows-Only/Find-CustomFolderIcons.ps1</code> - Finds folders with a custom icon set via <code>desktop.ini</code>.</summary>

PowerShell · Windows-only
Full docs: [PowerShell/Windows-Only/README.md](PowerShell/Windows-Only/README.md#find-customfoldericonsps1)
</details>

### Dev & Git Tooling

<details>
<summary><code>Sync-GitRepository.ps1</code> - Pulls latest main from origin and interactively deletes orphaned local branches.</summary>

PowerShell · Cross-platform · PowerShell 7+, Git
Full docs: [PowerShell/README.md](PowerShell/README.md#sync-gitrepositoryps1)
</details>

<details>
<summary><code>Update-Repo.ps1</code> - Thin convenience wrapper for <code>Sync-GitRepository.ps1</code> (same behavior, shorter name).</summary>

PowerShell · Cross-platform · PowerShell 7+, Git
Full docs: [PowerShell/README.md](PowerShell/README.md#update-repops1)
</details>

<details>
<summary><code>Invoke-CodexSession.ps1</code> / <code>codex-sessions.py</code> - Lists/deletes local Codex CLI session storage (filesystem + SQLite).</summary>

PowerShell wrapper (Cross-platform, PowerShell 7+ + Python 3) around the Python implementation (Cross-platform, Python 3).
Full docs: [PowerShell/README.md](PowerShell/README.md#invoke-codexsessionps1) · [Python/README.md](Python/README.md#codex-sessionspy)
</details>

### Terminal & Environment

<details>
<summary><code>Show-AnsiDemo.ps1</code> - Prints an ANSI escape-code demo table to verify terminal styling.</summary>

PowerShell · Cross-platform · ANSI-capable terminal
Full docs: [PowerShell/Windows-Terminal/README.md](PowerShell/Windows-Terminal/README.md#show-ansidemops1)
</details>

### System Provisioning

<details>
<summary><code>Windows-Only/Invoke-ImageSeal.ps1</code> - Seals a Windows VM (logs/caches/profiles/services/DISM cleanup + confirmed Sysprep) before templating.</summary>

PowerShell · Windows-only · Elevated session, DELPROF2
Full docs: [PowerShell/Windows-Only/README.md](PowerShell/Windows-Only/README.md#invoke-imagesealps1)
</details>

---

Full details (parameters, examples, prerequisites) are in each folder's own README:
[PowerShell/README.md](PowerShell/README.md) ·
[Bash/README.md](Bash/README.md) ·
[PowerShell/Windows-Only/README.md](PowerShell/Windows-Only/README.md) ·
[PowerShell/Windows-Terminal/README.md](PowerShell/Windows-Terminal/README.md) ·
[Python/README.md](Python/README.md)

---
