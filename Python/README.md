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

---

## `Templates/`

`template.py` - the argparse-based skeleton every new Python script should be copied from. See
[.ai/CONVENTIONS.md](../.ai/CONVENTIONS.md) section 4 for the help-output shape it follows.
