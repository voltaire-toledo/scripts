# PowerShell Scripts

Utility scripts for image processing, file management, and icon conversion.

---

## Scripts

### `Invoke-CodexSession.ps1`

Lists and selectively deletes local Codex CLI session storage from `CODEX_HOME` or `~/.codex`. It removes the selected transcript file, `session_index.jsonl` row, `history.jsonl` rows, and matching SQLite metadata/log rows. Destructive operations prompt unless `--yes` is supplied.

**Prerequisites:** Python 3, because Codex stores part of its local session metadata in SQLite.

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

### `ConvertTo-ICO.ps1`

Converts a single SVG or PNG file into a multi-resolution `.ico` file containing sizes: 256×256, 64×64, 48×48, 32×32, 24×24, and 16×16. The output file is written to the same directory as the source file, named `<basename>_<ext>.ico`.

**Prerequisites:** [ImageMagick v7+](https://imagemagick.org/) installed and `magick` available on the system `PATH`.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-SourceFilePath` | Yes | Path to the source `.svg` or `.png` file. |

**Usage:**
```powershell
.\ConvertTo-ICO.ps1 -SourceFilePath "C:\Icons\logo.svg"
.\ConvertTo-ICO.ps1 "C:\Icons\image.png"
```

> **Note:** The output ICO is written to the same folder as the source file. Ensure you have write access to that folder.

---

### `Copy-SpotLightWallpapers.ps1`

Finds landscape-oriented images from the Windows Spotlight assets cache and copies them as `.jpg` files to a target directory. After copying, it optionally renames the files using the date-taken/acquired/modified metadata and image dimensions (delegating to the same logic as `Rename-jpgOnDateTaken.ps1`).

**Prerequisites:** .NET `System.Drawing` assembly (available by default on Windows).

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-TargetDir` | No | Destination directory for copied wallpapers. Defaults to the **current working directory**. |
| `-Help` / `-h` | No | Displays help and exits. |

Supports `-WhatIf` and `-Confirm` via `SupportsShouldProcess`.

**Usage:**
```powershell
# Copy to current working directory
.\Copy-SpotLightWallpapers.ps1

# Copy to a specific folder
.\Copy-SpotLightWallpapers.ps1 -TargetDir "C:\Wallpapers"

# Preview with help
.\Copy-SpotLightWallpapers.ps1 --help
```

---

### `Delete-EmptyFolders.ps1`

Recursively finds and deletes all empty subdirectories under a given root path (the root itself is never deleted). Processes deepest directories first to handle nested empty trees correctly. Prompts for confirmation unless `-Force` is supplied.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Root` | No | Root path to scan. Defaults to the **current working directory**. |
| `-Force` | No | Skips the confirmation prompt. |
| `-HideProgress` | No | Suppresses per-folder console output. |

**Usage:**
```powershell
# Interactively clean current directory
.\Delete-EmptyFolders.ps1

# Clean a specific path without prompting
.\Delete-EmptyFolders.ps1 -Root "D:\Photos" -Force

# Quiet mode
.\Delete-EmptyFolders.ps1 -Root "D:\Photos" -Force -HideProgress
```

---

### `get-jpg-dimensions.ps1`

Reports the pixel width and height of every `.jpg` file in the **current working directory**. Output is written to the console.

**Prerequisites:** .NET `System.Drawing` assembly (available by default on Windows).

**Parameters:** None — run from the directory containing the JPG files.

**Usage:**
```powershell
# Navigate to the folder first, then run
cd "C:\Photos"
.\get-jpg-dimensions.ps1
```

---

### `process-images.ps1`

Organizes image files from one or more source subfolders into year-based subdirectories under a root path. For each image it:

1. Appends a `_WIDTHxHEIGHT` dimension suffix to the filename (if not already present).
2. Reads the EXIF date taken (tags `0x9003` / `0x9004`) and moves the file to a `<Year>` subfolder under the root. Files with no usable date are placed in an `Undetermined` subfolder.
3. Handles filename collisions with a `_dup<n>` suffix.
4. Logs all activity to `TASKS.md` in the root directory.

**Supported formats:** `.jpg` `.jpeg` `.png` `.webp` `.bmp` `.tif` `.tiff` `.gif` `.heic`

**Prerequisites:** .NET `System.Drawing` assembly (available by default on Windows).

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-Root` | Yes | The root directory where year subfolders are created and `TASKS.md` is written. |
| `-Subfolders` | Yes | One or more subfolder names (relative to `-Root`) to scan for images. |

**Usage:**
```powershell
.\process-images.ps1 -Root "D:\Photos" -Subfolders "Imports","Camera"

# Multiple subfolders
.\process-images.ps1 -Root "D:\Photos" -Subfolders @("Imports", "Phone", "Scanner")
```

> **Note:** `TASKS.md` is created/appended in the `-Root` directory. Ensure you have write access there.

---

### `Rename-jpgOnDateTaken.ps1`

Renames `.jpg` files in a directory to a standardized `yyyy-MM-dd_WIDTHxHEIGHT_###.jpg` format. The date is sourced from Windows Shell metadata in priority order: *Date Taken → Date Acquired → Date Modified*. Files already matching the target pattern are skipped. Supports `-WhatIf` to preview changes without applying them.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-DirectoryPath` | No | Directory containing the JPG files. Defaults to the **current working directory**. |
| `-IndexStart` | No | Starting index number appended to the filename. Defaults to `1`. |

**Usage:**
```powershell
# Preview renames in the current directory
.\Rename-jpgOnDateTaken.ps1 -WhatIf

# Rename files in a specific folder
.\Rename-jpgOnDateTaken.ps1 -DirectoryPath "C:\Photos"

# Rename with a custom starting index
.\Rename-jpgOnDateTaken.ps1 -DirectoryPath "C:\Photos" -IndexStart 100 -WhatIf
```
