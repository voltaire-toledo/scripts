#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "Pillow>=10.0.0",
# ]
# ///
"""Resize and frame images with aspect-ratio containment, center cropping, or Lanczos upscaling.

Supports four framing modes (`contain` with transparent/color padding, `cover` center-crop,
`scale` proportional fit, and `stretch`), plus `--min-size` and `--max-size` bounds with
optional `_upscaled_<W>x<H>` filename tagging.

Prerequisites: Python 3.9+, Pillow (`pip install Pillow`).
Platform: Cross-platform.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Optional, Tuple
from PIL import Image, ImageColor, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent / "Common"))
from image_deps import load_image_any, normalize_help_argv  # noqa: E402

EPILOG = """\
Examples:
  resize-image-frame.py logo.png --size 512x512 --fit contain
      Fit logo.png inside a 512x512 transparent square without distorting aspect ratio.

  resize-image-frame.py icon.png --min-size 96x96 --tag-upscaled
      Upscale sub-96px icon using Lanczos resampling and tag filename with _upscaled_<W>x<H>.
"""


def parse_dims(dim_str: str) -> Tuple[int, int]:
    m = re.match(r"^(\d+)(?:[xX:](\d+))?$", dim_str.strip())
    if not m:
        raise ValueError(f"Invalid dimension '{dim_str}'. Use WxH (e.g. 512x512) or single integer (e.g. 512).")
    w = int(m.group(1))
    h = int(m.group(2)) if m.group(2) else w
    return w, h


def parse_rgba(color_str: str) -> Tuple[int, int, int, int]:
    if not color_str or color_str.lower() in {"transparent", "none"}:
        return (0, 0, 0, 0)
    rgb = ImageColor.getrgb(color_str)
    return (rgb[0], rgb[1], rgb[2], 255) if len(rgb) == 3 else rgb


def resize_single_image(
    input_path: Path,
    size: Optional[Tuple[int, int]] = None,
    min_size: Optional[Tuple[int, int]] = None,
    max_size: Optional[Tuple[int, int]] = None,
    fit: str = "contain",
    bg_color: str = "transparent",
    output_path: Optional[Path] = None,
    tag_upscaled: bool = False,
    suffix_dims: bool = False,
) -> Path:
    img = load_image_any(input_path)
    orig_w, orig_h = img.size
    was_upscaled = False

    with img:
        work = img.convert("RGBA")

        if min_size:
            min_w, min_h = min_size
            if work.width < min_w or work.height < min_h:
                scale_factor = max(min_w / work.width, min_h / work.height)
                new_w = max(min_w, int(round(work.width * scale_factor)))
                new_h = max(min_h, int(round(work.height * scale_factor)))
                work = work.resize((new_w, new_h), resample=Image.Resampling.LANCZOS)
                was_upscaled = True

        if max_size:
            max_w, max_h = max_size
            if work.width > max_w or work.height > max_h:
                work.thumbnail((max_w, max_h), resample=Image.Resampling.LANCZOS)

        if size:
            target_w, target_h = size
            if target_w > orig_w or target_h > orig_h:
                was_upscaled = True

            if fit == "contain":
                work = ImageOps.pad(
                    work, (target_w, target_h), method=Image.Resampling.LANCZOS,
                    color=parse_rgba(bg_color), centering=(0.5, 0.5),
                )
            elif fit == "cover":
                work = ImageOps.fit(
                    work, (target_w, target_h), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5),
                )
            elif fit == "scale":
                scale_factor = min(target_w / work.width, target_h / work.height)
                new_w = max(1, int(round(work.width * scale_factor)))
                new_h = max(1, int(round(work.height * scale_factor)))
                work = work.resize((new_w, new_h), resample=Image.Resampling.LANCZOS)
            elif fit == "stretch":
                work = work.resize((target_w, target_h), resample=Image.Resampling.LANCZOS)
            else:
                raise ValueError(f"Unknown fit mode: {fit}")

        final_w, final_h = work.size

        if output_path is None:
            stem = input_path.stem
            if suffix_dims or tag_upscaled:
                stem = re.sub(r"(?:_upscaled)?[-_]\d+x\d+$", "", stem, flags=re.IGNORECASE)
            infix = "_upscaled" if (tag_upscaled and was_upscaled) else ""
            dim_tag = f"_{final_w}x{final_h}"
            out_ext = ".png" if input_path.suffix.lower() == ".svg" else input_path.suffix
            output_path = input_path.with_name(f"{stem}{infix}{dim_tag}{out_ext}")
        else:
            output_path.parent.mkdir(parents=True, exist_ok=True)

        if output_path.suffix.lower() in {".jpg", ".jpeg", ".bmp"}:
            bg = Image.new("RGB", work.size, (255, 255, 255))
            bg.paste(work, mask=work.split()[3])
            bg.save(output_path, quality=92, optimize=True)
        else:
            work.save(output_path, optimize=True)

    return output_path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="resize-image-frame",
        description=__doc__.splitlines()[0],
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", help="Source image path.")
    parser.add_argument("-s", "--size", default=None, help="Target dimensions WxH or W (e.g., 512x512 or 512).")
    parser.add_argument("--min-size", default=None, help="Minimum WxH bound (upscales smaller images via Lanczos).")
    parser.add_argument("--max-size", default=None, help="Maximum WxH bound (downscales larger images proportionally).")
    parser.add_argument(
        "--fit", choices=["contain", "cover", "scale", "stretch"], default="contain",
        help="Framing mode: contain (pad), cover (center crop), scale (proportional), stretch.",
    )
    parser.add_argument("--bg-color", default="transparent", help="Padding color for 'contain' mode (default: transparent).")
    parser.add_argument("--tag-upscaled", action="store_true", help="Tag filename with _upscaled_<W>x<H> when upscaled.")
    parser.add_argument("--suffix-dims", action="store_true", help="Append _<W>x<H> to output filename.")
    parser.add_argument("-o", "--output", default=None, help="Explicit output path.")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(normalize_help_argv(argv))
    in_path = Path(args.input).resolve()
    out_path = Path(args.output).resolve() if args.output else None

    size_tuple = parse_dims(args.size) if args.size else None
    min_tuple = parse_dims(args.min_size) if args.min_size else None
    max_tuple = parse_dims(args.max_size) if args.max_size else None

    if not any([size_tuple, min_tuple, max_tuple]):
        print("Error: Specify at least one of --size, --min-size, or --max-size.", file=sys.stderr)
        return 1

    res = resize_single_image(
        in_path, size=size_tuple, min_size=min_tuple, max_size=max_tuple,
        fit=args.fit, bg_color=args.bg_color, output_path=out_path,
        tag_upscaled=args.tag_upscaled, suffix_dims=args.suffix_dims,
    )
    print(f"Resized: {res}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
