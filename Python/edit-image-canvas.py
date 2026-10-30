#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "Pillow>=10.0.0",
# ]
# ///
"""Trim transparent margins, pad images to a 1:1 square, or apply circle/rounded alpha masks.

Uses 4x supersampled geometry for anti-aliased circular avatar and rounded-rectangle masks,
preserving existing transparency channels via alpha multiplication.

Prerequisites: Python 3.9+, Pillow (`pip install Pillow`).
Platform: Cross-platform.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Optional
from PIL import Image, ImageChops, ImageDraw, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent / "Common"))
from image_deps import load_image_any, normalize_help_argv  # noqa: E402

EPILOG = """\
Examples:
  edit-image-canvas.py KIP-PROFILE.jpg --trim --mask circle --size 512 -o kip-avatar.png
      Crop transparent margins, fit to 512x512, and apply an anti-aliased circular cutout.

  edit-image-canvas.py logo.png --trim --pad-square --padding 16
      Crop transparent whitespace and center the logo inside a 1:1 square with 16px margin.
"""


def trim_transparent(img: Image.Image, padding: int = 0) -> Image.Image:
    rgba = img.convert("RGBA")
    alpha = rgba.split()[3]
    bbox = alpha.getbbox()
    if bbox:
        rgba = rgba.crop(bbox)
    if padding > 0:
        w, h = rgba.size
        padded = Image.new("RGBA", (w + padding * 2, h + padding * 2), (0, 0, 0, 0))
        padded.paste(rgba, (padding, padding))
        return padded
    return rgba


def pad_to_square(img: Image.Image, padding: int = 0) -> Image.Image:
    rgba = img.convert("RGBA")
    side = max(rgba.width, rgba.height) + (padding * 2)
    return ImageOps.pad(
        rgba, (side, side), method=Image.Resampling.LANCZOS,
        color=(0, 0, 0, 0), centering=(0.5, 0.5),
    )


def apply_alpha_mask(img: Image.Image, mask_type: str, radius_spec: str = "20%") -> Image.Image:
    rgba = img.convert("RGBA")
    w, h = rgba.size
    ss = 4
    mask_hi = Image.new("L", (w * ss, h * ss), 0)
    draw = ImageDraw.Draw(mask_hi)

    if mask_type == "circle":
        draw.ellipse((0, 0, w * ss - 1, h * ss - 1), fill=255)
    elif mask_type == "rounded":
        s = radius_spec.strip()
        if s.endswith("%"):
            pct = float(s[:-1]) / 100.0
            r = int(round(min(w, h) * pct))
        else:
            r = int(round(float(s.rstrip("px"))))
        draw.rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), radius=r * ss, fill=255)
    else:
        raise ValueError(f"Unsupported mask type: {mask_type}")

    mask = mask_hi.resize((w, h), resample=Image.Resampling.LANCZOS)
    orig_alpha = rgba.split()[3]
    combined_alpha = ImageChops.multiply(orig_alpha, mask)
    rgba.putalpha(combined_alpha)
    return rgba


def process_canvas(
    input_path: Path,
    trim: bool = False,
    pad_square: bool = False,
    padding: int = 0,
    size: Optional[int] = None,
    mask: Optional[str] = None,
    radius: str = "20%",
    output_path: Optional[Path] = None,
) -> Path:
    img = load_image_any(input_path)
    with img:
        work = img.convert("RGBA")

        if trim:
            work = trim_transparent(work, padding=0)

        if pad_square or mask == "circle":
            work = pad_to_square(work, padding=padding)
        elif padding > 0:
            w, h = work.size
            padded = Image.new("RGBA", (w + padding * 2, h + padding * 2), (0, 0, 0, 0))
            padded.paste(work, (padding, padding))
            work = padded

        if size:
            work = ImageOps.pad(
                work, (size, size), method=Image.Resampling.LANCZOS,
                color=(0, 0, 0, 0), centering=(0.5, 0.5),
            )

        if mask:
            work = apply_alpha_mask(work, mask_type=mask, radius_spec=radius)

        if output_path is None:
            suffix_tag = f"_{mask}" if mask else ("_square" if pad_square else "_trimmed")
            output_path = input_path.with_name(f"{input_path.stem}{suffix_tag}.png")
        else:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            if output_path.suffix.lower() in {".jpg", ".jpeg"}:
                output_path = output_path.with_suffix(".png")

        work.save(output_path, format="PNG", optimize=True)

    return output_path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="edit-image-canvas",
        description=__doc__.splitlines()[0],
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", help="Source image path.")
    parser.add_argument("--trim", action="store_true", help="Trim transparent whitespace margins.")
    parser.add_argument("--pad-square", action="store_true", help="Center image inside a 1:1 transparent square.")
    parser.add_argument("--padding", type=int, default=0, help="Add transparent margin padding in pixels (default: 0).")
    parser.add_argument("-s", "--size", type=int, default=None, help="Optional target square dimension (e.g. 512).")
    parser.add_argument("--mask", choices=["circle", "rounded"], default=None, help="Apply circle or rounded-rect mask.")
    parser.add_argument(
        "--radius", default="20%",
        help="Corner radius for --mask rounded (e.g. '20%%' or '32', default: 20%%).",
    )
    parser.add_argument("-o", "--output", default=None, help="Output PNG file path.")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(normalize_help_argv(argv))
    in_path = Path(args.input).resolve()
    out_path = Path(args.output).resolve() if args.output else None

    res = process_canvas(
        in_path, trim=args.trim, pad_square=args.pad_square, padding=args.padding,
        size=args.size, mask=args.mask, radius=args.radius, output_path=out_path,
    )
    print(f"Created: {res}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
