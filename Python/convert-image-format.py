#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "Pillow>=10.0.0",
# ]
# ///
"""Convert images between PNG, JPG, WEBP, AVIF, BMP, TIFF, ICO, TGA, SVG, HEIC, and GIF.

Uses Python Pillow for native raster conversion, ImageMagick (`magick`) or `resvg`/`cairosvg`
for vector SVG/EPS/PDF and HEIC inputs, and FFmpeg/ImageMagick for animated formats.
Transparent RGBA inputs converted to opaque formats (JPG/BMP) are composited cleanly over
`--bg-color` (default `#FFFFFF`) rather than turning transparent pixels black.

Prerequisites: Python 3.9+, Pillow (`pip install Pillow`), optional ImageMagick/FFmpeg.
Platform: Cross-platform.
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Tuple
from PIL import Image, ImageColor

sys.path.insert(0, str(Path(__file__).resolve().parent / "Common"))
from image_deps import load_image_any, normalize_help_argv, save_multi_res_ico  # noqa: E402

SUPPORTED_INPUT_EXTS = {
    ".png", ".jpg", ".jpeg", ".webp", ".avif", ".bmp", ".tiff", ".tif",
    ".ico", ".tga", ".ppm", ".svg", ".heic", ".heif", ".gif", ".apng", ".eps", ".pdf"
}

FORMAT_MAP = {
    "png": ("PNG", ".png"),
    "jpg": ("JPEG", ".jpg"),
    "jpeg": ("JPEG", ".jpg"),
    "webp": ("WEBP", ".webp"),
    "avif": ("AVIF", ".avif"),
    "bmp": ("BMP", ".bmp"),
    "tiff": ("TIFF", ".tiff"),
    "tif": ("TIFF", ".tif"),
    "ico": ("ICO", ".ico"),
    "tga": ("TGA", ".tga"),
    "gif": ("GIF", ".gif"),
}

EPILOG = """\
Examples:
  convert-image-format.py hero.svg -f webp
      Rasterize hero.svg and save as hero.webp at quality 90.

  convert-image-format.py ./photos -f avif -q 85 --strip-exif --recurse --force
      Recursively convert all images in ./photos to AVIF with EXIF stripped.
"""


def parse_bg_color(color_str: str) -> Tuple[int, int, int]:
    try:
        rgb = ImageColor.getrgb(color_str)
        return rgb[:3]
    except Exception:
        return (255, 255, 255)


def convert_file(
    input_path: Path,
    target_format: str,
    output_path: Path | None = None,
    quality: int = 90,
    lossless: bool = False,
    strip_exif: bool = False,
    bg_color: str = "#FFFFFF",
    svg_size: int = 1024,
    force: bool = False,
) -> Path:
    fmt_key = target_format.lower().lstrip(".")
    if fmt_key not in FORMAT_MAP:
        raise ValueError(
            f"Unsupported target format '{target_format}'. Supported: {', '.join(sorted(FORMAT_MAP.keys()))}"
        )

    pil_fmt, out_ext = FORMAT_MAP[fmt_key]

    if output_path is None:
        output_path = input_path.with_suffix(out_ext)
        if output_path == input_path and not force:
            output_path = input_path.with_name(f"{input_path.stem}_converted{out_ext}")
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)

    if output_path.exists() and not force and output_path != input_path:
        raise FileExistsError(f"Output file already exists (use --force to overwrite): {output_path}")

    if pil_fmt == "ICO":
        return save_multi_res_ico(input_path, output_path=output_path, force=True)

    img = load_image_any(input_path, svg_size=svg_size)

    with img:
        is_animated = getattr(img, "is_animated", False) and getattr(img, "n_frames", 1) > 1
        if is_animated and pil_fmt in {"GIF", "WEBP"}:
            magick_bin = shutil.which("magick")
            if magick_bin:
                cmd = [magick_bin, str(input_path), "-quality", str(quality), str(output_path)]
                subprocess.run(cmd, check=True, capture_output=True)
                return output_path

        if pil_fmt in {"JPEG", "BMP"}:
            if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
                rgba = img.convert("RGBA")
                bg = Image.new("RGB", rgba.size, parse_bg_color(bg_color))
                bg.paste(rgba, mask=rgba.split()[3])
                out_img = bg
            else:
                out_img = img.convert("RGB")
        else:
            out_img = img.convert("RGBA") if img.mode == "P" else img.copy()

        save_kwargs = {}
        if not strip_exif and "exif" in img.info and pil_fmt in {"JPEG", "WEBP", "TIFF", "PNG"}:
            save_kwargs["exif"] = img.info["exif"]

        if pil_fmt in {"JPEG", "WEBP", "AVIF"}:
            save_kwargs["quality"] = quality
        if pil_fmt == "JPEG":
            save_kwargs["optimize"] = True
        elif pil_fmt == "PNG":
            save_kwargs["optimize"] = True
        elif pil_fmt == "WEBP":
            save_kwargs["lossless"] = lossless
            save_kwargs["method"] = 6
        elif pil_fmt == "AVIF" and lossless:
            save_kwargs["quality"] = 100

        out_img.save(output_path, format=pil_fmt, **save_kwargs)

    return output_path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="convert-image-format",
        description=__doc__.splitlines()[0],
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", help="Source image file or directory.")
    parser.add_argument(
        "-f", "--format", required=True,
        help="Target format (png, jpg, webp, avif, ico, tiff, bmp, tga, gif).",
    )
    parser.add_argument("-o", "--output", default=None, help="Output file or directory path.")
    parser.add_argument("-q", "--quality", type=int, default=90, help="Quality 1-100 (default: 90).")
    parser.add_argument("--lossless", action="store_true", help="Use lossless compression for WebP/AVIF.")
    parser.add_argument("--strip-exif", action="store_true", help="Strip EXIF metadata.")
    parser.add_argument(
        "--bg-color", default="#FFFFFF",
        help="Background color when flattening alpha to JPG/BMP (default: #FFFFFF).",
    )
    parser.add_argument(
        "--svg-size", type=int, default=1024,
        help="Rasterization dimension for SVG inputs (default: 1024).",
    )
    parser.add_argument("-r", "--recurse", action="store_true", help="Recursively convert a directory.")
    parser.add_argument("--force", action="store_true", help="Overwrite existing output files.")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(normalize_help_argv(argv))
    in_path = Path(args.input).resolve()

    if not in_path.exists():
        print(f"Error: Input path not found: {in_path}", file=sys.stderr)
        return 1

    if in_path.is_dir():
        pattern = "**/*" if args.recurse else "*"
        files = [p for p in in_path.glob(pattern) if p.is_file() and p.suffix.lower() in SUPPORTED_INPUT_EXTS]
        out_dir = Path(args.output).resolve() if args.output else None
        for f in files:
            target_out = (out_dir / f.with_suffix(FORMAT_MAP[args.format.lower().lstrip(".")][1]).name) if out_dir else None
            try:
                res = convert_file(
                    f, args.format, output_path=target_out, quality=args.quality,
                    lossless=args.lossless, strip_exif=args.strip_exif, bg_color=args.bg_color,
                    svg_size=args.svg_size, force=args.force,
                )
                print(f"Converted: {f.name} -> {res}")
            except Exception as e:
                print(f"Error converting {f}: {e}", file=sys.stderr)
    else:
        out_file = Path(args.output).resolve() if args.output else None
        try:
            res = convert_file(
                in_path, args.format, output_path=out_file, quality=args.quality,
                lossless=args.lossless, strip_exif=args.strip_exif, bg_color=args.bg_color,
                svg_size=args.svg_size, force=args.force,
            )
            print(f"Created: {res} ({res.stat().st_size / 1024:.1f} KB)")
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
