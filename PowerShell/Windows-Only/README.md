# Windows-Only Scripts

Scripts that depend on something with no cross-platform equivalent - COM automation, NTFS
directory junctions, the Windows Spotlight assets cache, or `System.Drawing.Common` (which
Microsoft dropped real non-Windows support for in modern .NET). See
[.ai/CONVENTIONS.md](../../.ai/CONVENTIONS.md) section 5 for the rule that put them here, and
`PowerShell/README.md` for the cross-platform scripts these mirror or supersede.

---

## Scripts

### `Find-CustomFolderIcons.ps1`

Recursively searches a directory for hidden `desktop.ini` files and reports each folder's
custom icon path (`IconResource`/`IconFile`, with any trailing icon index stripped).

**Why Windows-only:** `desktop.ini`-based folder customization is a Windows Explorer-specific
mechanism with no cross-platform equivalent.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-SearchPath` | No | Directory to start searching from. Defaults to the current user's profile directory. Positional. |

**Usage:**
```powershell
.\Find-CustomFolderIcons.ps1
.\Find-CustomFolderIcons.ps1 -SearchPath "C:\Users\Jigs\Documents"
```

---

### `Get-JpgDimensions.ps1`

Legacy `System.Drawing`-based implementation of image-dimension reporting. Superseded by
[`Get-ImageDimensions.ps1`](../Get-ImageDimensions.ps1) (ImageMagick-based, cross-platform) -
use that one unless you specifically need this fallback and don't have ImageMagick installed.

**Why Windows-only:** `System.Drawing.Common`.

**Usage:**
```powershell
cd "C:\Photos"
.\Get-JpgDimensions.ps1
```

---

### `Group-ImageFilesByYear.ps1`

Legacy `System.Drawing`-based implementation of the year-grouping workflow. Superseded by
[`Group-ImageFilesByYear.ps1`](../Group-ImageFilesByYear.ps1) (ImageMagick-based, cross-platform,
same name, one level up) - use that one unless you specifically need this fallback.

**Why Windows-only:** `System.Drawing.Common`.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Root` | Yes | Root directory where year subfolders are created and `TASKS.md` is written. |
| `-Subfolders` | Yes | One or more subfolder names (relative to `-Root`) to scan for images. |

**Usage:**
```powershell
.\Group-ImageFilesByYear.ps1 -Root "D:\Photos" -Subfolders "Imports","Camera"
```

---

### `Copy-SpotlightWallpapers.ps1`

Copies landscape-oriented images from the Windows Spotlight assets cache to a target directory,
optionally renaming them by Date Taken (delegates to the same logic as
`Rename-JpgOnDateTaken.ps1`, duplicated locally rather than shared - see the note in
[.ai/CONVENTIONS.md](../../.ai/CONVENTIONS.md) section 5 about keeping shared logic in `Common/`; this
is a known, accepted exception, not an oversight).

**Why Windows-only:** the Windows Spotlight assets cache and the `Shell.Application` COM object
used for the rename step don't exist off Windows.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-TargetDir` | No | Destination directory for copied wallpapers. Defaults to the current working directory. |
| `-NonInteractive` | No | Skips the optional rename prompt and every pause, for unattended runs. |

**Usage:**
```powershell
.\Copy-SpotlightWallpapers.ps1 -TargetDir "C:\Wallpapers"

# Unattended (scheduled task, no prompts/pauses)
.\Copy-SpotlightWallpapers.ps1 -TargetDir "C:\Wallpapers" -NonInteractive
```

---

### `Rename-JpgOnDateTaken.ps1`

Renames `.jpg` files in a directory to a standardized `yyyy-MM-dd_WIDTHxHEIGHT_###.jpg` format,
sourcing the date from Windows Shell metadata (Date Taken → Date Acquired → Date Modified).

**Why Windows-only:** the `Shell.Application` COM object used to read Date
Taken/Acquired/Modified metadata doesn't exist off Windows.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-DirectoryPath` | No | Directory containing the JPG files. Defaults to the current working directory. |
| `-IndexStart` | No | Starting index number appended to the filename. Defaults to `1`. |

**Usage:**
```powershell
.\Rename-JpgOnDateTaken.ps1 -DirectoryPath "C:\Photos" -WhatIf
```

---

### `Invoke-ImageSeal.ps1`

Seals a Windows VM in preparation for Sysprep and deployment as a golden image template: clears
logs/caches/profiles, disables update services, runs a DISM component-store cleanup, and more.
Sysprep itself is never run automatically - it's a separate, final step that always requires
typing `yes` at an explicit prompt, regardless of other parameters. See
[`Invoke-ImageSeal.md`](Invoke-ImageSeal.md) for the full task list, external tool requirements,
and the bugs found/fixed during adoption from the original script.

**Why Windows-only:** Sysprep, DISM, `wevtutil`, Group Policy, Windows services, and Appx
packages have no cross-platform equivalent.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-SkipManifest` | No | Skips the free-text admin change-log prompt. |
| `-PromptAll` | No | Prompts y/n before every task except manifest collection and Sysprep. |
| `-DryRun` | No | Preview mode - equivalent to `-WhatIf`. Every task, including ones that shell out to external tools, is gated behind this. |

**Usage:**
```powershell
.\Invoke-ImageSeal.ps1 -DryRun
.\Invoke-ImageSeal.ps1 -SkipManifest -PromptAll
```

---

### `New-ResilientJunction.ps1`

Creates a directory junction that's resilient to drive-letter reassignment, by resolving the
target into its Volume GUID path first.

**Why Windows-only:** NTFS directory junctions and Volume GUID paths have no cross-platform
equivalent. `New-Item -ItemType SymbolicLink` is the portable alternative when drive-letter
resilience specifically isn't required.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-TargetPath` | Yes | The real directory to link to. |
| `-LinkPath` | Yes | Where to create the junction. Fails without changes if this already exists. |

**Usage:**
```powershell
.\New-ResilientJunction.ps1 -TargetPath "E:\dotfiles" -LinkPath "$env:USERPROFILE\dotfiles"
```
