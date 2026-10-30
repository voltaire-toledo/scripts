#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "Pillow>=10.0.0",
# ]
# ///
"""Audit Python version, Pillow codecs, and external CLI tools for image conversion.

Checks Python runtime (>= 3.9 required), Pillow installation (including WebP and AVIF
support), ImageMagick (`magick`), FFmpeg (`ffmpeg`), `resvg`, `cairosvg`, and `pillow-heif`.
Prints a human-readable capability report with viable package-manager installation commands
for any missing dependencies, or emits structured JSON when `--json` is passed.

Prerequisites: Python 3.9+.
Platform: Cross-platform.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict

sys.path.insert(0, str(Path(__file__).resolve().parent / "Common"))
from image_deps import normalize_help_argv, run_all_checks  # noqa: E402

EPILOG = """\
Examples:
  test-image-deps.py
      Run a human-readable audit of image conversion engines and print remediation options.

  test-image-deps.py --json
      Emit the dependency and capability report as structured JSON for headless agents.
"""


def print_human_report(report: Dict[str, Any]) -> None:
    print("=== convert-image Dependency & Capability Audit ===")
    print(f"OS Platform      : {report['os']}")
    print(f"Core Raster Ready: {'YES' if report['core_ready'] else 'NO (Action Required)'}")
    print(f"SVG Vector Ready : {'YES' if report['svg_ready'] else 'NO (Install ImageMagick, resvg, or cairosvg)'}")
    print(f"Animated Ready   : {'YES' if report['animated_ready'] else 'PARTIAL (Pillow only; install FFmpeg/ImageMagick)'}")
    print("-" * 60)

    missing_items = []
    for key, item in report["checks"].items():
        status = "OK" if item["installed"] else ("MISSING (REQUIRED)" if item["required"] else "OPTIONAL (Not Installed)")
        ver = f" [{item['version']}]" if item.get("version") else ""
        print(f"* {item['name']:22s}: {status}{ver}")
        if key == "pillow" and item["installed"]:
            feats = item.get("features", {})
            print(f"    |-- WebP codec      : {'OK' if feats.get('webp') else 'MISSING'}")
            print(f"    +-- AVIF codec      : {'OK' if feats.get('avif') else 'MISSING'}")
        if not item["installed"]:
            missing_items.append(item)

    if missing_items:
        print("\n=== Viable Resolution Options for Uninstalled Dependencies ===")
        for item in missing_items:
            tag = "REQUIRED" if item["required"] else "OPTIONAL"
            print(f"\n[{tag}] {item['name']} -- {item.get('purpose', 'Core dependency')}")
            for mgr, cmd in item.get("remediation", {}).items():
                print(f"  * {mgr:8s}: {cmd}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="test-image-deps",
        description=__doc__.splitlines()[0],
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output structured JSON report instead of human-readable text.",
    )
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(normalize_help_argv(argv))
    report = run_all_checks()
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_human_report(report)
    return 0 if report["core_ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
