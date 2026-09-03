#!/usr/bin/env python3
"""TODO: One line synopsis of what this script does.

TODO: Full description - what it does, its defaults, and any side effects (files written,
things deleted/moved, network calls, external tools invoked, etc). This module docstring is
also what argparse's `description=` should echo (see build_parser below) so `--help` and
`pydoc` show the same thing.
"""

from __future__ import annotations

import argparse
import sys

# NOTE: -h/--help are automatic with argparse - no extra wiring needed, unlike PowerShell.
# See .ai/CONVENTIONS.md section 4 for the shape every script's --help output should follow:
# synopsis, description, parameters (automatic), and real usage examples (via epilog below).

EPILOG = """\
Examples:
  verb-noun.py
      TODO: describe what the minimal invocation does.

  verb-noun.py --path "/some/dir" --force
      TODO: describe a more realistic invocation.
"""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="verb-noun",  # TODO: rename to this script's real kebab-case name.
        description=__doc__.splitlines()[0],  # TODO: or write a dedicated description string.
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--path",
        default=".",
        help="TODO: describe this parameter. Defaults to the current working directory.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="TODO: if this script mutates/deletes anything, give it a non-interactive bypass "
        "flag (--force/--yes) so it can run unattended - see .ai/CONVENTIONS.md section 6.",
    )

    # If this script needs multiple distinct actions (list/delete/backup, etc - see
    # codex-sessions.py for a real example), use subparsers instead of a flat flag set:
    #
    # sub = parser.add_subparsers(dest="command", required=True)
    # list_parser = sub.add_parser("list", help="...")
    # list_parser.set_defaults(func=list_command)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    # TODO: replace with the script's real behavior.
    raise SystemExit(
        "This is a template, not a runnable script. Copy it to a verb-noun.py name and fill "
        "in the TODOs (see .ai/CONVENTIONS.md)."
    )


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
