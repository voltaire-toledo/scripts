#!/usr/bin/env python3
"""Shared image loading, dependency auditing, ICO generation, and help-flag normalization
for the Python image conversion scripts.
"""

from __future__ import annotations

import io
import json
import platform
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

MIN_PYTHON = (3, 9)
REC_PYTHON = (3, 10)
DEFAULT_ICO_SIZES = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)]


def normalize_help_argv(argv: List[str]) -> List[str]:
    """Normalize PowerShell/CMD help tokens (-Help, -help, /?) to --help so all 5 produce
    identical output per CONVENTIONS.md §4.
    """
    help_tokens = {"-help", "-Help", "-HELP", "/?"}
    return ["--help" if arg in help_tokens else arg for arg in argv]


def check_python_version() -> Dict[str, Any]:
    ver = sys.version_info
    ver_str = f"{ver.major}.{ver.minor}.{ver.micro}"
    ok = (ver.major, ver.minor) >= MIN_PYTHON
    return {
        "name": "Python Runtime",
        "required": True,
        "installed": ok,
        "version": ver_str,
        "minimum": f"{MIN_PYTHON[0]}.{MIN_PYTHON[1]}",
        "recommended": f"{REC_PYTHON[0]}.{REC_PYTHON[1]}+",
        "path": sys.executable,
        "remediation": {
            "winget": "winget install Python.Python.3.12",
            "scoop": "scoop install python",
            "brew": "brew install python@3.12",
            "apt": "sudo apt update && sudo apt install -y python3 python3-pip python3-venv",
        } if not ok else {},
    }


def check_pillow() -> Dict[str, Any]:
    try:
        import PIL
        from PIL import features

        webp_ok = bool(features.check("webp"))
        avif_ok = bool(features.check("avif"))
        return {
            "name": "Pillow (PIL)",
            "required": True,
            "installed": True,
            "version": PIL.__version__,
            "features": {
                "webp": webp_ok,
                "avif": avif_ok,
            },
            "remediation": {},
        }
    except ImportError:
        return {
            "name": "Pillow (PIL)",
            "required": True,
            "installed": False,
            "version": None,
            "features": {"webp": False, "avif": False},
            "remediation": {
                "pip": f'"{sys.executable}" -m pip install --upgrade Pillow',
                "uv": "uv pip install --system Pillow",
            },
        }


def check_cli_tool(
    binary_names: Tuple[str, ...],
    display_name: str,
    version_arg: str = "-version",
    required: bool = False,
    purpose: str = "",
    remediation: Optional[Dict[str, str]] = None,
) -> Dict[str, Any]:
    found_path = None
    for b in binary_names:
        found_path = shutil.which(b)
        if found_path:
            break

    version_line = None
    if found_path:
        try:
            proc = subprocess.run(
                [found_path, version_arg],
                capture_output=True,
                text=True,
                timeout=5,
            )
            out = (proc.stdout or proc.stderr or "").strip().splitlines()
            if out:
                version_line = out[0].strip()
        except Exception:
            version_line = "Installed (version query skipped)"

    return {
        "name": display_name,
        "required": required,
        "installed": bool(found_path),
        "version": version_line,
        "path": found_path,
        "purpose": purpose,
        "remediation": {} if found_path else (remediation or {}),
    }


def check_optional_python_mod(mod_name: str, pkg_name: str, purpose: str) -> Dict[str, Any]:
    try:
        mod = __import__(mod_name)
        ver = getattr(mod, "__version__", "installed")
        return {
            "name": pkg_name,
            "required": False,
            "installed": True,
            "version": ver,
            "purpose": purpose,
            "remediation": {},
        }
    except ImportError:
        return {
            "name": pkg_name,
            "required": False,
            "installed": False,
            "version": None,
            "purpose": purpose,
            "remediation": {
                "pip": f'"{sys.executable}" -m pip install {pkg_name}',
                "uv": f"uv pip install --system {pkg_name}",
            },
        }


def run_all_checks() -> Dict[str, Any]:
    py_info = check_python_version()
    pil_info = check_pillow()
    magick_info = check_cli_tool(
        ("magick",),
        "ImageMagick (magick)",
        version_arg="-version",
        required=False,
        purpose="SVG vector rasterization, HEIC/RAW/EPS/PDF support, and CLI fallback conversion",
        remediation={
            "winget": "winget install ImageMagick.ImageMagick",
            "scoop": "scoop install imagemagick",
            "choco": "choco install imagemagick",
            "brew": "brew install imagemagick",
            "apt": "sudo apt install -y imagemagick",
        },
    )
    ffmpeg_info = check_cli_tool(
        ("ffmpeg",),
        "FFmpeg",
        version_arg="-version",
        required=False,
        purpose="Animated GIF, animated WebP, and APNG frame conversion/optimization",
        remediation={
            "scoop": "scoop install ffmpeg",
            "winget": "winget install Gyan.FFmpeg",
            "choco": "choco install ffmpeg",
            "brew": "brew install ffmpeg",
            "apt": "sudo apt install -y ffmpeg",
        },
    )
    resvg_info = check_cli_tool(
        ("resvg",),
        "resvg",
        version_arg="--version",
        required=False,
        purpose="High-speed Rust SVG renderer (optional alternative to ImageMagick/cairosvg)",
        remediation={
            "scoop": "scoop install resvg",
            "winget": "winget install RazrFalcon.resvg",
            "cargo": "cargo install resvg",
            "brew": "brew install resvg",
        },
    )
    cairosvg_info = check_optional_python_mod(
        "cairosvg",
        "cairosvg",
        purpose="Pure-Python SVG rasterizer (optional if ImageMagick or resvg is installed)",
    )
    heif_info = check_optional_python_mod(
        "pillow_heif",
        "pillow-heif",
        purpose="Direct Pillow HEIC/HEIF support (optional if ImageMagick is installed)",
    )

    svg_capable = any(
        x["installed"] for x in (magick_info, resvg_info, cairosvg_info)
    )
    core_ready = py_info["installed"] and pil_info["installed"]

    return {
        "os": platform.system(),
        "core_ready": core_ready,
        "svg_ready": svg_capable,
        "animated_ready": ffmpeg_info["installed"] or magick_info["installed"],
        "checks": {
            "python": py_info,
            "pillow": pil_info,
            "imagemagick": magick_info,
            "ffmpeg": ffmpeg_info,
            "resvg": resvg_info,
            "cairosvg": cairosvg_info,
            "pillow_heif": heif_info,
        },
    }


def load_image_any(input_path: Path, svg_size: int = 1024):
    """Load standard raster formats via Pillow, and automatically route SVG / HEIC / RAW / EPS
    through cairosvg, resvg, or ImageMagick (magick) when needed.
    """
    from PIL import Image

    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    ext = input_path.suffix.lower()

    if ext in {".heic", ".heif"}:
        try:
            import pillow_heif
            pillow_heif.register_heif_opener()
        except ImportError:
            pass

    if ext == ".svg":
        try:
            import cairosvg
            png_bytes = cairosvg.svg2png(
                url=str(input_path), output_width=svg_size, output_height=svg_size
            )
            img = Image.open(io.BytesIO(png_bytes))
            img.load()
            return img
        except ImportError:
            pass

        resvg_bin = shutil.which("resvg")
        if resvg_bin:
            import tempfile
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
                tmp_path = Path(tmp.name)
            try:
                subprocess.run(
                    [resvg_bin, "-w", str(svg_size), "-h", str(svg_size), str(input_path), str(tmp_path)],
                    check=True,
                    capture_output=True,
                )
                img = Image.open(tmp_path)
                img.load()
                return img
            finally:
                tmp_path.unlink(missing_ok=True)

        magick_bin = shutil.which("magick")
        if magick_bin:
            proc = subprocess.run(
                [
                    magick_bin,
                    "-background",
                    "none",
                    "-density",
                    "300",
                    str(input_path),
                    "-resize",
                    f"{svg_size}x{svg_size}",
                    "PNG32:-",
                ],
                check=True,
                capture_output=True,
            )
            img = Image.open(io.BytesIO(proc.stdout))
            img.load()
            return img

        raise RuntimeError(
            "SVG conversion requires at least one SVG engine (ImageMagick, resvg, or cairosvg).\n"
            "Viable options to resolve:\n"
            "  * Winget: winget install ImageMagick.ImageMagick\n"
            "  * Scoop:  scoop install imagemagick  (or: scoop install resvg)\n"
            f'  * Pip:    "{sys.executable}" -m pip install cairosvg'
        )

    try:
        img = Image.open(input_path)
        img.load()
        return img
    except Exception as pil_err:
        magick_bin = shutil.which("magick")
        if magick_bin:
            proc = subprocess.run(
                [magick_bin, str(input_path), "PNG32:-"],
                check=True,
                capture_output=True,
            )
            img = Image.open(io.BytesIO(proc.stdout))
            img.load()
            return img
        raise RuntimeError(
            f"Pillow could not decode '{input_path.name}' ({pil_err}) and ImageMagick is not installed.\n"
            "Viable options to resolve:\n"
            "  * Install ImageMagick: winget install ImageMagick.ImageMagick (or: scoop install imagemagick)\n"
            f'  * For HEIC files:      "{sys.executable}" -m pip install pillow-heif'
        ) from pil_err


def save_multi_res_ico(input_path: Path, output_path: Optional[Path] = None, force: bool = False) -> Path:
    """Convert a single image into a 7-tier PNG-compressed Windows .ico file."""
    from PIL import Image, ImageOps

    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    if output_path is None:
        target_dir = input_path.parent
        output_path = target_dir / f"{input_path.stem}.ico"
        if output_path.exists() and not force:
            timestamp = datetime.now().strftime("%y%m%d%H%M%S")
            output_path = target_dir / f"{input_path.stem}_{timestamp}.ico"
    else:
        output_path.parent.mkdir(parents=True, exist_ok=True)

    img = load_image_any(input_path, svg_size=1024)
    with img:
        img_rgba = img.convert("RGBA")
        square_img = ImageOps.pad(
            img_rgba,
            (256, 256),
            method=Image.Resampling.LANCZOS,
            color=(0, 0, 0, 0),
            centering=(0.5, 0.5),
        )
        square_img.save(output_path, format="ICO", sizes=DEFAULT_ICO_SIZES)

    return output_path
