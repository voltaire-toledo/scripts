# Bash Scripts

Standalone Bash scripts for cross-platform automation and filesystem maintenance.
See [.ai/CONVENTIONS.md](../.ai/CONVENTIONS.md) for repository conventions.

Every script below responds to `-h` and `--help`.

---

## Scripts

### `remove-macos-artifacts.sh`

Recursively scans a directory tree and deletes macOS-specific metadata and shadow files:
- AppleDouble resource fork / shadow files (`._*`)
- Desktop services store files (`.DS_Store`)
- macOS zip extraction metadata directories (`__MACOSX`)
- macOS volume metadata directories (`.Spotlight-V100`, `.Trashes`, `.fseventsd`)

**Prerequisites:** Bash 4+, POSIX find.

**Platform:** Cross-platform (macOS, Linux, WSL, Git Bash on Windows).

**Parameters:**

| Option | Description |
|---|---|
| `-p, --path <DIR>` | Directory to clean. Defaults to current working directory. |
| `-f, --force` | Skips upfront confirmation prompt for unattended execution. |
| `-d, --dry-run` | Previews files and directories that would be deleted without deleting anything. |
| `-q, --quiet` | Suppresses per-file deletion output. |
| `-h, --help` | Displays usage instructions. |

**Usage:**
```bash
# Interactively clean current directory
./remove-macos-artifacts.sh

# Non-interactive cleanup on a target directory
./remove-macos-artifacts.sh -p "/path/to/code" -f

# Dry-run preview
./remove-macos-artifacts.sh --path "~/Projects" --dry-run
```
