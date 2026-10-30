# Python Scripts

Standalone CLI utilities. See [.ai/CONVENTIONS.md](../.ai/CONVENTIONS.md) for the naming/help/platform
rules these follow, and `Templates/template.py` for the starting point for a new one.

---

## Scripts

### `codex-sessions.py`

Lists and selectively deletes local Codex CLI session storage from `CODEX_HOME` or `~/.codex`.
Removes the selected transcript file, `session_index.jsonl` row, `history.jsonl` rows, and
matching SQLite metadata/log rows. Destructive operations prompt unless `--yes` is supplied.
Invoked directly, or via `PowerShell/Invoke-CodexSession.ps1` (a thin wrapper for users who'd
rather stay in PowerShell).

**Prerequisites:** Python 3 (uses only the standard library).

**Platform:** Cross-platform.

**Usage:**
```bash
# List sessions
python codex-sessions.py list

# Preview deletion by full ID or unambiguous prefix
python codex-sessions.py delete 019e626d --dry-run

# Delete after explicit confirmation bypass
python codex-sessions.py delete 019e626d --yes

# Preview deleting all local sessions
python codex-sessions.py clear --dry-run

# Back up Codex home before cleanup
python codex-sessions.py backup ~/codex-backup
```

### `test-image-deps.py`

Audits Python version (`>= 3.9`), Pillow codecs (`WebP`, `AVIF`), and external CLI tools (`ImageMagick`, `FFmpeg`, `resvg`, `cairosvg`, `pillow-heif`) for the `convert-image` skill, printing viable installation options for any missing dependency.

**Prerequisites:** Python 3.9+.

**Platform:** Cross-platform.

**Usage:**
```bash
python test-image-deps.py
python test-image-deps.py --json
```

### `convert-image-format.py`

Converts single images or directories between `PNG`, `JPG`, `WEBP`, `AVIF`, `BMP`, `TIFF`, `ICO`, `TGA`, `SVG`, `HEIC`, and `GIF` using Pillow, ImageMagick (`magick`), and FFmpeg.

**Prerequisites:** Python 3.9+, Pillow (`pip install Pillow`), optional ImageMagick/FFmpeg.

**Platform:** Cross-platform.

**Usage:**
```bash
python convert-image-format.py hero.svg -f webp
python convert-image-format.py ./photos -f avif -q 85 --strip-exif --recurse --force
```

### `resize-image-frame.py`

Resizes and frames images with aspect-ratio containment (`contain`), center cropping (`cover`), proportional scaling (`scale`), or exact bounds (`--min-size`, `--max-size`) using Lanczos resampling.

**Prerequisites:** Python 3.9+, Pillow (`pip install Pillow`).

**Platform:** Cross-platform.

**Usage:**
```bash
python resize-image-frame.py logo.png --size 512x512 --fit contain
python resize-image-frame.py icon.png --min-size 96x96 --tag-upscaled
```

### `edit-image-canvas.py`

Trims transparent margins (`--trim`), pads non-square images to `1:1` (`--pad-square`), and applies 4x supersampled anti-aliased `circle` or `rounded` masks.

**Prerequisites:** Python 3.9+, Pillow (`pip install Pillow`).

**Platform:** Cross-platform.

**Usage:**
```bash
python edit-image-canvas.py KIP-PROFILE.jpg --trim --mask circle --size 512 -o kip-avatar.png
python edit-image-canvas.py logo.png --trim --pad-square --padding 16
```

### `convert-to-ico.py`

Converts images into 7-tier PNG-compressed Windows `.ico` containers (`256x256` down to `16x16`) or extracts the highest-resolution master PNG (`--extract-png`).

**Prerequisites:** Python 3.9+, Pillow (`pip install Pillow`).

**Platform:** Cross-platform.

**Usage:**
```bash
python convert-to-ico.py KIP-PROFILE.jpg -o KIP-PROFILE.ico -f
python convert-to-ico.py legacy.ico --extract-png
```

### `new-web-icon-bundle.py`

Generates a complete Web, PWA, and OpenGraph icon bundle (`favicon.ico`, `16x16`, `32x32`, `48x48`, `apple-touch-icon.png`, `icon-192x192.png`, `icon-512x512.png`, `og-image.png`, `site.webmanifest`, `head-tags.html`).

**Prerequisites:** Python 3.9+, Pillow (`pip install Pillow`).

**Platform:** Cross-platform.

**Usage:**
```bash
python new-web-icon-bundle.py logo.svg -o ./public/icons --app-name "QODE Fleet"
```

---

## `Common/`

`image_deps.py` - shared dependency checker, universal image loader (Pillow + ImageMagick/resvg/cairosvg fallback), 7-tier ICO writer, and help-flag normalizer (`-Help`, `-h`, `--help`, `-help`, `/?`).

---

## `Templates/`

`template.py` - the argparse-based skeleton every new Python script should be copied from. See
[.ai/CONVENTIONS.md](../.ai/CONVENTIONS.md) section 4 for the help-output shape it follows.
