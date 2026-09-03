#!/usr/bin/env python3
"""List and delete local Codex CLI session records.

This deliberately keeps filesystem cleanup and SQLite cleanup in one Python
program so callers do not need fragile shell quoting for multi-line SQL logic.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


SESSION_TABLES = {
    "threads": ("id",),
    "stage1_outputs": ("thread_id",),
    "thread_dynamic_tools": ("thread_id",),
    "thread_spawn_edges": ("parent_thread_id", "child_thread_id"),
}

LOG_TABLES = {
    "logs": ("thread_id",),
}


@dataclass
class SessionRecord:
    session_id: str
    title: str
    source: str
    cwd: str
    updated_at: int | None
    archived: bool | None
    path: Path | None
    size: int


def default_codex_home() -> Path:
    if os.environ.get("CODEX_HOME"):
        return Path(os.environ["CODEX_HOME"]).expanduser()
    if os.name == "nt":
        user_profile = os.environ.get("USERPROFILE")
        if user_profile:
            return Path(user_profile) / ".codex"
    return Path.home() / ".codex"


def resolve_under(base: Path, candidate: Path) -> Path:
    base_resolved = base.resolve()
    candidate_resolved = candidate.resolve()
    try:
        candidate_resolved.relative_to(base_resolved)
    except ValueError as exc:
        raise SystemExit(f"Refusing path outside Codex home: {candidate_resolved}") from exc
    return candidate_resolved


def parse_jsonl(path: Path, max_lines: int = 500) -> dict[str, str | int | None]:
    meta: dict[str, str | int | None] = {
        "id": None,
        "title": "",
        "cwd": "",
        "source": "",
        "updated_at": None,
    }
    first_user_message = ""

    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            for line_number, line in enumerate(handle, start=1):
                if line_number > max_lines:
                    break
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue

                timestamp = row.get("timestamp")
                if timestamp:
                    meta["updated_at"] = parse_timestamp(timestamp)

                payload = row.get("payload") if isinstance(row.get("payload"), dict) else {}
                if row.get("type") == "session_meta" and payload:
                    meta["id"] = payload.get("id") or meta["id"]
                    meta["cwd"] = payload.get("cwd") or meta["cwd"]
                    meta["source"] = payload.get("source") or meta["source"]
                elif row.get("type") == "event_msg" and payload:
                    if payload.get("type") == "user_message" and not first_user_message:
                        message = payload.get("message")
                        if isinstance(message, str):
                            first_user_message = message.strip()
    except OSError:
        pass

    if first_user_message:
        meta["title"] = first_user_message.splitlines()[0][:80]
    return meta


def parse_timestamp(value: str) -> int | None:
    try:
        normalized = value.replace("Z", "+00:00")
        return int(datetime.fromisoformat(normalized).timestamp())
    except ValueError:
        return None


def read_state_rows(codex_home: Path) -> dict[str, SessionRecord]:
    db_path = codex_home / "state_5.sqlite"
    if not db_path.exists():
        return {}

    records: dict[str, SessionRecord] = {}
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        con.row_factory = sqlite3.Row
        tables = {
            row[0]
            for row in con.execute(
                "select name from sqlite_master where type='table'"
            ).fetchall()
        }
        if "threads" not in tables:
            return {}
        for row in con.execute(
            "select id, rollout_path, updated_at, source, cwd, title, archived "
            "from threads order by updated_at desc"
        ):
            path = Path(row["rollout_path"]) if row["rollout_path"] else None
            records[row["id"]] = SessionRecord(
                session_id=row["id"],
                title=row["title"] or "",
                source=row["source"] or "",
                cwd=row["cwd"] or "",
                updated_at=row["updated_at"],
                archived=bool(row["archived"]),
                path=path,
                size=path.stat().st_size if path and path.exists() else 0,
            )
    finally:
        con.close()
    return records


def read_session_index(codex_home: Path) -> dict[str, str]:
    index_path = codex_home / "session_index.jsonl"
    titles: dict[str, str] = {}
    if not index_path.exists():
        return titles
    with index_path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            session_id = row.get("id")
            title = row.get("thread_name")
            if isinstance(session_id, str) and isinstance(title, str):
                titles[session_id] = title
    return titles


def discover_session_files(codex_home: Path) -> dict[str, SessionRecord]:
    sessions_dir = codex_home / "sessions"
    records: dict[str, SessionRecord] = {}
    if not sessions_dir.exists():
        return records

    for path in sessions_dir.rglob("*"):
        if not path.is_file():
            continue
        meta = parse_jsonl(path)
        session_id = meta["id"]
        if not isinstance(session_id, str) or not session_id:
            continue
        records[session_id] = SessionRecord(
            session_id=session_id,
            title=str(meta["title"] or ""),
            source=str(meta["source"] or ""),
            cwd=str(meta["cwd"] or ""),
            updated_at=meta["updated_at"] if isinstance(meta["updated_at"], int) else None,
            archived=None,
            path=path,
            size=path.stat().st_size,
        )
    return records


def load_sessions(codex_home: Path) -> list[SessionRecord]:
    records = discover_session_files(codex_home)
    state_records = read_state_rows(codex_home)
    index_titles = read_session_index(codex_home)

    for session_id, state_record in state_records.items():
        if session_id in records:
            existing = records[session_id]
            existing.title = state_record.title or index_titles.get(session_id, existing.title)
            existing.source = state_record.source or existing.source
            existing.cwd = state_record.cwd or existing.cwd
            existing.updated_at = state_record.updated_at or existing.updated_at
            existing.archived = state_record.archived
            existing.path = state_record.path or existing.path
            existing.size = state_record.size or existing.size
        else:
            state_record.title = state_record.title or index_titles.get(session_id, "")
            records[session_id] = state_record

    for session_id, title in index_titles.items():
        if session_id in records and not records[session_id].title:
            records[session_id].title = title

    return sorted(
        records.values(),
        key=lambda item: item.updated_at or 0,
        reverse=True,
    )


def format_time(epoch: int | None) -> str:
    if not epoch:
        return ""
    return datetime.fromtimestamp(epoch, timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")


def list_sessions(args: argparse.Namespace) -> int:
    codex_home = args.codex_home.resolve()
    sessions = load_sessions(codex_home)
    if args.json:
        print(json.dumps([session_to_json(item) for item in sessions], indent=2))
        return 0

    if not sessions:
        print(f"No Codex sessions found under {codex_home}")
        return 0

    print(f"Codex home: {codex_home}")
    print(f"{'ID':36}  {'UPDATED':16}  {'SIZE':>9}  {'A':1}  TITLE")
    for item in sessions:
        title = item.title or "(untitled)"
        archived = "Y" if item.archived else ""
        print(
            f"{item.session_id:36}  {format_time(item.updated_at):16}  "
            f"{item.size:9}  {archived:1}  {title}"
        )
    return 0


def session_to_json(item: SessionRecord) -> dict[str, object]:
    return {
        "id": item.session_id,
        "title": item.title,
        "source": item.source,
        "cwd": item.cwd,
        "updated_at": item.updated_at,
        "archived": item.archived,
        "path": str(item.path) if item.path else None,
        "size": item.size,
    }


def resolve_ids(wanted: Iterable[str], sessions: list[SessionRecord]) -> set[str]:
    ids = {item.session_id for item in sessions}
    resolved: set[str] = set()
    for token in wanted:
        exact = token if token in ids else None
        if exact:
            resolved.add(exact)
            continue
        matches = [session_id for session_id in ids if session_id.startswith(token)]
        if not matches:
            raise SystemExit(f"No session matches '{token}'.")
        if len(matches) > 1:
            raise SystemExit(f"Ambiguous session prefix '{token}': {', '.join(matches)}")
        resolved.add(matches[0])
    return resolved


def rewrite_jsonl_without_ids(path: Path, id_field: str, delete_ids: set[str], dry_run: bool) -> int:
    if not path.exists():
        return 0
    kept: list[str] = []
    removed = 0
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                kept.append(line)
                continue
            if row.get(id_field) in delete_ids:
                removed += 1
            else:
                kept.append(line)
    if removed and not dry_run:
        path.write_text("".join(kept), encoding="utf-8")
    return removed


def sqlite_delete(db_path: Path, table_columns: dict[str, tuple[str, ...]], delete_ids: set[str], dry_run: bool) -> int:
    if not db_path.exists():
        return 0

    removed = 0
    con = sqlite3.connect(db_path)
    try:
        tables = {
            row[0]
            for row in con.execute(
                "select name from sqlite_master where type='table'"
            ).fetchall()
        }
        for table, columns in table_columns.items():
            if table not in tables:
                continue
            present_columns = {
                row[1]
                for row in con.execute(f"pragma table_info({quote_identifier(table)})")
            }
            where_parts = []
            params: list[str] = []
            for column in columns:
                if column not in present_columns:
                    continue
                where_parts.append(f"{quote_identifier(column)} in ({placeholders(delete_ids)})")
                params.extend(sorted(delete_ids))
            if not where_parts:
                continue
            where_clause = " or ".join(where_parts)
            count = con.execute(
                f"select count(*) from {quote_identifier(table)} where {where_clause}",
                params,
            ).fetchone()[0]
            removed += int(count)
            if count and not dry_run:
                con.execute(
                    f"delete from {quote_identifier(table)} where {where_clause}",
                    params,
                )
        if not dry_run:
            con.commit()
            con.execute("vacuum")
    finally:
        con.close()
    return removed


def quote_identifier(value: str) -> str:
    if not value.replace("_", "").isalnum():
        raise ValueError(f"Unsafe SQLite identifier: {value}")
    return f'"{value}"'


def placeholders(values: set[str]) -> str:
    return ",".join("?" for _ in values)


def delete_sessions(args: argparse.Namespace) -> int:
    codex_home = args.codex_home.resolve()
    resolve_under(codex_home, codex_home)
    sessions = load_sessions(codex_home)
    delete_ids = resolve_ids(args.session_ids, sessions)
    selected = [item for item in sessions if item.session_id in delete_ids]

    if not selected:
        print("No matching sessions selected.")
        return 0

    print("Selected sessions:")
    for item in selected:
        print(f"  {item.session_id}  {format_time(item.updated_at)}  {item.title or '(untitled)'}")

    if not args.yes and not args.dry_run:
        answer = input("Delete these local Codex session records? Type 'delete' to continue: ")
        if answer != "delete":
            print("Cancelled.")
            return 2

    files_removed = 0
    bytes_removed = 0
    for item in selected:
        if not item.path:
            continue
        path = resolve_under(codex_home, item.path)
        if path.exists() and path.is_file():
            files_removed += 1
            bytes_removed += path.stat().st_size
            if not args.dry_run:
                path.unlink()

    empty_dirs_removed = 0
    sessions_dir = codex_home / "sessions"
    if sessions_dir.exists() and not args.dry_run:
        for path in sorted(sessions_dir.rglob("*"), key=lambda p: len(p.parts), reverse=True):
            if path.is_dir():
                try:
                    path.rmdir()
                    empty_dirs_removed += 1
                except OSError:
                    pass

    index_rows = rewrite_jsonl_without_ids(
        codex_home / "session_index.jsonl", "id", delete_ids, args.dry_run
    )
    history_rows = rewrite_jsonl_without_ids(
        codex_home / "history.jsonl", "session_id", delete_ids, args.dry_run
    )
    state_rows = sqlite_delete(codex_home / "state_5.sqlite", SESSION_TABLES, delete_ids, args.dry_run)
    log_rows = sqlite_delete(codex_home / "logs_2.sqlite", LOG_TABLES, delete_ids, args.dry_run)

    action = "Would delete" if args.dry_run else "Deleted"
    print(
        f"{action}: {files_removed} transcript file(s), {bytes_removed} bytes, "
        f"{index_rows} index row(s), {history_rows} history row(s), "
        f"{state_rows} state row(s), {log_rows} log row(s)."
    )
    if empty_dirs_removed:
        print(f"Removed {empty_dirs_removed} empty session directorie(s).")
    return 0


def clear_sessions(args: argparse.Namespace) -> int:
    sessions = load_sessions(args.codex_home.resolve())
    args.session_ids = [item.session_id for item in sessions]
    if not args.session_ids:
        print("No sessions to clear.")
        return 0
    return delete_sessions(args)


def backup_codex_home(args: argparse.Namespace) -> int:
    source = args.codex_home.resolve()
    target = Path(args.target).expanduser().resolve()
    resolve_under(source, source)
    if target.exists():
        raise SystemExit(f"Backup target already exists: {target}")
    shutil.copytree(source, target)
    print(f"Backed up {source} -> {target}")
    return 0


EPILOG = """\
Examples:
  codex-sessions.py list
      List local Codex sessions.

  codex-sessions.py delete 019e626d --dry-run
      Preview deleting a session by full ID or unambiguous prefix.

  codex-sessions.py delete 019e626d --yes
      Delete a session after explicit confirmation bypass.

  codex-sessions.py clear --dry-run
      Preview deleting all local sessions.

  codex-sessions.py backup ~/codex-backup
      Copy the Codex home directory before running a cleanup.
"""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="codex-sessions",
        description="List and selectively delete local Codex session storage.",
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--codex-home",
        type=Path,
        default=default_codex_home(),
        help="Codex home directory. Defaults to CODEX_HOME or ~/.codex.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    list_parser = sub.add_parser("list", help="List local Codex sessions.")
    list_parser.add_argument("--json", action="store_true", help="Emit JSON.")
    list_parser.set_defaults(func=list_sessions)

    delete_parser = sub.add_parser("delete", help="Delete selected local sessions.")
    delete_parser.add_argument("session_ids", nargs="+", help="Session UUIDs or unambiguous prefixes.")
    delete_parser.add_argument("--yes", "-y", action="store_true", help="Do not prompt for confirmation.")
    delete_parser.add_argument("--dry-run", action="store_true", help="Show what would be deleted.")
    delete_parser.set_defaults(func=delete_sessions)

    clear_parser = sub.add_parser("clear", help="Delete all local sessions.")
    clear_parser.add_argument("--yes", "-y", action="store_true", help="Do not prompt for confirmation.")
    clear_parser.add_argument("--dry-run", action="store_true", help="Show what would be deleted.")
    clear_parser.set_defaults(func=clear_sessions)

    backup_parser = sub.add_parser("backup", help="Copy Codex home before cleanup.")
    backup_parser.add_argument("target", help="Backup destination directory.")
    backup_parser.set_defaults(func=backup_codex_home)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.codex_home = args.codex_home.expanduser()
    if not args.codex_home.exists():
        raise SystemExit(f"Codex home does not exist: {args.codex_home}")
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
