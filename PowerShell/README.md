# PowerShell Scripts

Utility scripts for image processing, file management, symlink maintenance, and icon
conversion. See [.ai/CONVENTIONS.md](../.ai/CONVENTIONS.md) for the naming/help/platform rules every
script here follows, and `Templates/New-Script.Template.ps1` for the starting point for a new
one.

Every script below responds identically to `-Help`, `-h`, `--help`, `-help`, and `/?`.

---

## Folders

- **`Common/`** - shared, dot-sourced helpers (`ScriptHelp.ps1`, `ImageMagick.ps1`). Not scripts
  you run directly.
- **`Templates/`** - copy-from-this skeleton for a new script.
- **`Windows-Only/`** - scripts that depend on something with no cross-platform equivalent (COM
  automation, NTFS junctions, the Spotlight cache, `System.Drawing.Common`). See its own
  [README](Windows-Only/README.md).
- **`Windows-Terminal/`** - Windows Terminal configuration notes and a verification script. See
  its own [README](Windows-Terminal/README.md).

---

## Scripts

### `Sync-GitRepository.ps1`

Pulls the latest main branch from origin, prunes remote tracking references, and interactively
prompts to delete orphaned local branches (merged or deleted on remote) one-by-one.

**Prerequisites:** PowerShell 7+, Git CLI.

**Platform:** Cross-platform.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Path` | No | Git repository root or subfolder. Defaults to current working directory. |
| `-MainBranch` | No | Main branch name. Auto-detects `main`/`master` if omitted. |
| `-Remote` | No | Remote name to fetch and pull from. Defaults to `origin`. |
| `-Force` | No | Deletes all identified orphan branches without interactive prompts (Alias: `-Yes`). |
| `-NonInteractive` | No | Audits and lists orphan branches without modifying or prompting (exit code 1 if orphans exist). |

Supports `-WhatIf`/`-Confirm`.

**Usage:**
```powershell
# Refresh repo, switch/pull main, and interactively delete orphan branches
.\Sync-GitRepository.ps1

# Non-interactive auto-cleanup
.\Sync-GitRepository.ps1 -Force

# Preview actions with WhatIf
.\Sync-GitRepository.ps1 -WhatIf
```

---

### `Update-Repo.ps1`

Thin convenience wrapper around `Sync-GitRepository.ps1` - forwards every parameter straight
through. Exists for the shorter, more memorable invocation; behavior is identical to calling
`Sync-GitRepository.ps1` directly.

**Prerequisites:** PowerShell 7+, Git CLI.

**Platform:** Cross-platform.

**Parameters:** same as `Sync-GitRepository.ps1` (`-Path`, `-MainBranch`, `-Remote`, `-Force`/`-Yes`,
`-NonInteractive`). Supports `-WhatIf`/`-Confirm`.

**Usage:**
```powershell
# Update the current repo, prompting to delete any orphaned local branches
.\Update-Repo.ps1

# Non-interactive auto-cleanup
.\Update-Repo.ps1 -Force
```

---

### `Repair-Symlinks.ps1`

Recursively finds broken symlinks/junctions and repairs, deletes, or defers each one -
interactively, or automatically via `-BestEffort` (searches a separate directory tree for a
same-named replacement, matching file-vs-directory type). A relative target is resolved against
the link's own containing folder, not the current directory. Repair creates the replacement link
under a temporary name first, so a failed repair never leaves you with neither link.

**Prerequisites:** PowerShell 7.0+.

**Platform:** Cross-platform.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Path` | No | Root to scan recursively. Defaults to the current working directory. |
| `-NonInteractive` | No | Reports broken links and exits without prompting (exit code 1 if any found) - for a dotfiles bootstrap/CI check. Cannot combine with `-BestEffort`. |
| `-BestEffort` | No | Auto-repairs each broken link by searching `-TargetPath` for a same-named, same-type replacement; defers rather than guessing if zero or multiple matches are found. Combine with `-WhatIf` to preview. |
| `-TargetPath` | No | Directory to search when `-BestEffort` is used. Required with `-BestEffort`. |

Supports `-WhatIf`/`-Confirm`.

**Usage:**
```powershell
# Interactively fix broken links under the current directory
.\Repair-Symlinks.ps1

# Preview only
.\Repair-Symlinks.ps1 -Path ~/dotfiles -WhatIf

# CI/bootstrap health check
.\Repair-Symlinks.ps1 -Path ~/dotfiles -NonInteractive

# Auto-repair by matching filenames found under another directory tree
.\Repair-Symlinks.ps1 -Path ~/dotfiles -BestEffort -TargetPath D:\CODE\dotfiles -WhatIf
```

---

### `Invoke-CodexSession.ps1`

Lists and selectively deletes local Codex CLI session storage from `CODEX_HOME` or `~/.codex`
by forwarding to `Python/codex-sessions.py`. Destructive operations prompt unless `--yes` is
supplied.

**Prerequisites:** PowerShell 7+, Python 3 (Codex stores part of its session metadata in
SQLite).

**Platform:** Cross-platform.

**Usage:**
```powershell
# List sessions
.\Invoke-CodexSession.ps1 list

# Preview deletion by full ID or unambiguous prefix
.\Invoke-CodexSession.ps1 delete 019e626d --dry-run

# Delete after explicit confirmation bypass
.\Invoke-CodexSession.ps1 delete 019e626d --yes

# Preview deleting all local sessions
.\Invoke-CodexSession.ps1 clear --dry-run
```

---

### `ConvertTo-Ico.ps1`

Converts a single SVG or PNG file into a multi-resolution `.ico` file (256×256, 64×64, 48×48,
32×32, 24×24, 16×16). Output is written next to the source file as `<basename>_<ext>.ico`,
overwriting it if it already exists.

**Prerequisites:** [ImageMagick v7+](https://imagemagick.org/), with `magick` on `PATH`.

**Platform:** Cross-platform (wherever ImageMagick v7+ is installed).

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-SourceFilePath` | Yes | Path to the source `.svg` or `.png` file. Positional. |

Supports `-WhatIf`/`-Confirm`.

**Usage:**
```powershell
.\ConvertTo-Ico.ps1 -SourceFilePath "C:\Icons\logo.svg"
.\ConvertTo-Ico.ps1 "C:\Icons\image.png"
```

---

### `Get-ImageDimensions.ps1`

Reports the pixel width/height (and EXIF date, if present) of image files in a directory, via
ImageMagick. Cross-platform successor to `Windows-Only/Get-JpgDimensions.ps1`.

**Prerequisites:** ImageMagick (any binary name resolvable by `Common/ImageMagick.ps1`: `magick`,
`identify`, or `convert`).

**Platform:** Cross-platform.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Path` | No | Directory to scan. Defaults to the current working directory. |
| `-Filter` | No | Glob filter for which files to scan. Defaults to `*.jpg`. |

**Usage:**
```powershell
.\Get-ImageDimensions.ps1
.\Get-ImageDimensions.ps1 -Path "C:\Photos" -Filter "*.png"
```

---

### `Group-ImageFilesByYear.ps1`

Organizes image files from source subfolders into year-based subfolders under a root path:
appends a `_WIDTHxHEIGHT` suffix, reads the EXIF date (falling back to file modified time) to
pick a `<Year>` folder (or `Undetermined`), resolves name collisions with `_dup<n>`, and logs
everything to `TASKS.md`. Cross-platform successor to
`Windows-Only/Group-ImageFilesByYear.ps1`.

**Supported formats:** whatever ImageMagick can read - `.jpg` `.jpeg` `.png` `.webp` `.bmp`
`.tif` `.tiff` `.gif` `.heic`, etc.

**Prerequisites:** ImageMagick (see `Common/ImageMagick.ps1`).

**Platform:** Cross-platform.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Root` | Yes | Root directory where year subfolders are created and `TASKS.md` is written. |
| `-Subfolders` | Yes | One or more subfolder names (relative to `-Root`) to scan for images. |

Supports `-WhatIf`/`-Confirm`.

**Usage:**
```powershell
.\Group-ImageFilesByYear.ps1 -Root "D:\Photos" -Subfolders "Imports","Camera"
.\Group-ImageFilesByYear.ps1 -Root "D:\Photos" -Subfolders "Imports" -WhatIf
```

---

### `Remove-EmptyFolders.ps1`

Recursively finds and deletes all empty subdirectories under a root path (the root itself is
never deleted). Processes deepest directories first. Prompts for confirmation once up front
unless `-Force` is supplied.

**Platform:** Cross-platform.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Root` | No | Root path to scan. Defaults to the current working directory. |
| `-Force` | No | Skips the upfront confirmation prompt. |
| `-HideProgress` | No | Suppresses per-folder console output. |

Supports `-WhatIf`/`-Confirm`.

**Usage:**
```powershell
.\Remove-EmptyFolders.ps1
.\Remove-EmptyFolders.ps1 -Root "D:\Photos" -Force
```

---

### `Remove-MacOsArtifacts.ps1`

Recursively scans a directory tree and deletes macOS-specific metadata and shadow files:
- AppleDouble resource fork / shadow files (`._*`)
- Desktop services store files (`.DS_Store`)
- macOS zip extraction metadata directories (`__MACOSX`)
- macOS volume metadata directories (`.Spotlight-V100`, `.Trashes`, `.fseventsd`)

**Platform:** Cross-platform.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Path` | No | Root directory path to scan. Defaults to current working directory. |
| `-Force` | No | Skips the upfront confirmation prompt. |
| `-HideProgress` | No | Suppresses per-file console output. |

Supports `-WhatIf`/`-Confirm`.

**Usage:**
```powershell
# Interactively clean current working directory
.\Remove-MacOsArtifacts.ps1

# Non-interactive cleanup on a target directory
.\Remove-MacOsArtifacts.ps1 -Path "D:\CODE" -Force

# Preview what would be deleted without deleting
.\Remove-MacOsArtifacts.ps1 -Path "D:\CODE" -WhatIf
```
