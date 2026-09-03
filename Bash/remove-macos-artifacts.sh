#!/usr/bin/env bash
#
# SYNOPSIS:
#   remove-macos-artifacts.sh [-p|--path <DIR>] [-f|--force] [-d|--dry-run] [-q|--quiet] [-h|--help]
#
# DESCRIPTION:
#   Recursively scans a directory tree and deletes macOS-specific metadata and artifact files:
#     - AppleDouble resource fork / shadow files (._*)
#     - Desktop services store files (.DS_Store)
#     - macOS zip extraction metadata directories (__MACOSX)
#     - macOS volume metadata directories (.Spotlight-V100, .Trashes, .fseventsd)
#
# OPTIONS:
#   -p, --path <DIR>    Root directory to scan (defaults to current working directory)
#   -f, --force         Skip confirmation prompt (unattended mode)
#   -d, --dry-run       Preview which files/directories would be deleted without deleting
#   -q, --quiet         Suppress per-file progress output
#   -h, --help          Show this help message
#
# EXAMPLES:
#   ./remove-macos-artifacts.sh
#   ./remove-macos-artifacts.sh -p "/path/to/code" -f
#   ./remove-macos-artifacts.sh --path "~/Projects" --dry-run

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

TARGET_PATH="$(pwd)"
FORCE=false
DRY_RUN=false
QUIET=false

usage() {
    cat << 'EOF'
NAME:
  remove-macos-artifacts.sh - Recursively delete macOS artifact files and metadata folders.

SYNOPSIS:
  remove-macos-artifacts.sh [OPTIONS]

DESCRIPTION:
  Scans a directory tree and deletes common macOS metadata and shadow files left behind
  when sharing or backing up files across non-Apple filesystems (NTFS, SMB, FAT).
  Targets:
    - AppleDouble resource fork / shadow files (._*)
    - Desktop services store files (.DS_Store)
    - macOS zip extraction metadata directories (__MACOSX)
    - macOS volume metadata directories (.Spotlight-V100, .Trashes, .fseventsd)

OPTIONS:
  -p, --path <DIR>    Directory to clean (default: current working directory)
  -f, --force         Skip upfront confirmation prompt
  -d, --dry-run       Preview actions without making changes
  -q, --quiet         Suppress per-file deletion output
  -h, --help          Display this help message

EXAMPLES:
  ./remove-macos-artifacts.sh
  ./remove-macos-artifacts.sh -p "/mnt/d/CODE" -f
  ./remove-macos-artifacts.sh --dry-run
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--path)
            TARGET_PATH="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
            echo "Use -h or --help for usage instructions." >&2
            exit 1
            ;;
    esac
done

# Resolve absolute path
if [[ ! -d "$TARGET_PATH" ]]; then
    echo -e "${RED}Error: Directory '$TARGET_PATH' does not exist.${NC}" >&2
    exit 1
fi
TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"

# Upfront confirmation prompt
if [[ "$FORCE" = false && "$DRY_RUN" = false ]]; then
    echo -e "${YELLOW}WARNING: This script will delete all macOS artifacts (._*, .DS_Store, __MACOSX, etc.) in:${NC}"
    echo -e "${YELLOW}  $TARGET_PATH${NC}"
    read -r -p "Do you want to proceed? [y/N] " response
    if [[ ! "$response" =~ ^[yY]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

if [[ "$QUIET" = false ]]; then
    echo -e "${CYAN}Scanning for macOS artifacts in: $TARGET_PATH${NC}"
fi

FILE_COUNT=0
DIR_COUNT=0
TOTAL_BYTES=0

# 1. Process files: ._* and .DS_Store
while IFS= read -r -d '' file; do
    FILE_COUNT=$((FILE_COUNT + 1))
    
    # Get file size if stat is available
    SIZE=0
    if [[ "$OSTYPE" == "darwin"* ]]; then
        SIZE=$(stat -f%z "$file" 2>/dev/null || echo 0)
    else
        SIZE=$(stat -c%s "$file" 2>/dev/null || echo 0)
    fi
    TOTAL_BYTES=$((TOTAL_BYTES + SIZE))

    if [[ "$DRY_RUN" = true ]]; then
        if [[ "$QUIET" = false ]]; then
            echo -e "${GRAY}[DRY-RUN] Would delete file: $file (${SIZE} bytes)${NC}"
        fi
    else
        if [[ "$QUIET" = false ]]; then
            echo -e "${GRAY}Deleting file: $file... ${GREEN}Deleted${NC}"
        fi
        rm -f "$file"
    fi
done < <(find "$TARGET_PATH" -type f \( -name "._*" -o -name ".DS_Store" \) -print0 2>/dev/null)

# 2. Process directories: __MACOSX, .Spotlight-V100, .Trashes, .fseventsd
while IFS= read -r -d '' dir; do
    DIR_COUNT=$((DIR_COUNT + 1))
    if [[ "$DRY_RUN" = true ]]; then
        if [[ "$QUIET" = false ]]; then
            echo -e "${GRAY}[DRY-RUN] Would delete directory: $dir${NC}"
        fi
    else
        if [[ "$QUIET" = false ]]; then
            echo -e "${GRAY}Deleting directory: $dir... ${GREEN}Deleted${NC}"
        fi
        rm -rf "$dir"
    fi
done < <(find "$TARGET_PATH" -type d \( -name "__MACOSX" -o -name ".Spotlight-V100" -o -name ".Trashes" -o -name ".fseventsd" \) -print0 2>/dev/null)

# Summary
echo -e "${CYAN}==========================================${NC}"
if [[ "$DRY_RUN" = true ]]; then
    echo -e "${YELLOW}macOS Artifact Scan Complete (DRY-RUN)${NC}"
    echo "  Files identified      : $FILE_COUNT"
    echo "  Directories identified: $DIR_COUNT"
    echo "  Space to be freed     : $((TOTAL_BYTES / 1024)) KB ($TOTAL_BYTES bytes)"
else
    echo -e "${GREEN}macOS Artifact Cleanup Complete${NC}"
    echo "  Files deleted      : $FILE_COUNT"
    echo "  Directories deleted: $DIR_COUNT"
    echo "  Space freed        : $((TOTAL_BYTES / 1024)) KB ($TOTAL_BYTES bytes)"
fi
echo -e "${CYAN}==========================================${NC}"