#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "Pillow>=10.0.0",
# ]
# ///
"""Convert images into 7-tier PNG-compressed Windows ICO containers or extract master PNGs.

Embeds all 7 standard Windows and web resolutions (256x256, 128x128, 64x64, 48x48, 32x32,
24x24, 16x16) with aspect-ratio containment and 100% transparent padding. Also supports
`--extract-png` to extract the highest-resolution frame from an existing `.ico` (upscaling
sub-96px frames via Lanczos).

Prerequisites: Python 3.9+, Pillow (`pip install Pillow`).
Platform: Cross-platform.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent / "Common"))
from image_deps import normalize_help_argv, save_multi_res_ico  # noqa: E402

SUPPORTED_EXTS = {".png", ".webp", ".jpg", ".jpeg", ".svg", ".bmp", ".tiff", ".tif", ".avif", ".heic", ".heif"}

EPILOG = """\
Examples:
  convert-to-ico.py KIP-PROFILE.jpg -o KIP-PROFILE.ico -f
      Convert KIP-PROFILE.jpg into a 7-tier PNG-compressed KIP-PROFILE.ico.

  convert-to-ico.py legacy.ico --extract-png
      Extract the highest-resolution RGBA frame from legacy.ico into a PNG (min 96x96).
"""


def extract_png_from_ico(ico_path: Path, output_path: Path | None = None, min_size: int = 96) -> Path:
    if not ico_path.exists():
        raise FileNotFoundError(f"ICO file not found: {ico_path}")

    with Image.open(ico_path) as ico:
        sizes = ico.info.get("sizes", {ico.size})
        max_dim = max(sizes, key=lambda s: s[0] * s[1])
        try:
            ico.size = max_dim
            ico.load()
        except Exception:
            pass

        rgba = ico.convert("RGBA")
        was_upscaled = False
        if rgba.width < min_size or rgba.height < min_size:
            scale = max(min_size / rgba.width, min_size / rgba.height)
            new_w = max(min_size, int(round(rgba.width * scale)))
            new_h = max(min_size, int(round(rgba.height * scale)))
            rgba = rgba.resize((new_w, new_h), resample=Image.Resampling.LANCZOS)
            was_upscaled = True

        if output_path is None:
            tag = f"_upscaled_{rgba.width}x{rgba.height}" if was_upscaled else f"_{rgba.width}x{rgba.height}"
            output_path = ico_path.with_name(f"{ico_path.stem}{tag}.png")
        else:
            output_path.parent.mkdir(parents=True, exist_ok=True)

        rgba.save(output_path, format="PNG", optimize=True)

    return output_path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="convert-to-ico",
        description=__doc__.splitlines()[0],
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", help="Source image path, .ico file, or directory.")
    parser.add_argument("-o", "--output", default=None, help="Target .ico or .png path (optional).")
    parser.add_argument("-r", "--recurse", action="store_true", help="Recursively process a directory.")
    parser.add_argument("-f", "--force", action="store_true", help="Overwrite target files if they exist.")
    parser.add_argument(
        "--extract-png", action="store_true",
        help="Extract highest-resolution RGBA frame from .ico into a .png (min 96x96).",
    )
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(normalize_help_argv(argv))
    input_path = Path(args.input).resolve()

    if not input_path.exists():
        print(f"Error: Path '{input_path}' does not exist.", file=sys.stderr)
        return 1

    out_arg = Path(args.output).resolve() if args.output else None

    if args.extract_png:
        res = extract_png_from_ico(input_path, output_path=out_arg)
        print(f"Extracted PNG: {res}")
        return 0

    targets = []
    if input_path.is_dir():
        pattern = "**/*" if args.recurse else "*"
        for p in input_path.glob(pattern):
            if p.is_file() and p.suffix.lower() in SUPPORTED_EXTS:
                targets.append(p)
        if not targets:
            print("No supported image files found in directory.")
            return 0
    else:
        targets = [input_path]

    for target in targets:
        try:
            res = save_multi_res_ico(target, output_path=out_arg, force=args.force)
            print(f"Created ICO: {res} ({res.stat().st_size / 1024:.1f} KB)")
        except Exception as e:
            print(f"Error converting '{target}': {e}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
