# How to Sync with the Marketplace

This document outlines the procedure for syncing the scripts from this personal library (`VT-Scripts-Library`) to the public `VT-SKILLS-MarketPlace` repository, so they can be distributed as a portable AI skill via `skills.sh`.

## Synchronization Plan (Option 1: Portable/Sharable)

When syncing, we copy the actual scripts into a `scripts/` subdirectory inside the skill folder in the Marketplace. This ensures the skill has everything it needs to execute the tasks locally when installed on any machine.

### 1. Files to Copy (The Scripts)
The following directories and their contents are copied into the Marketplace:

**Source (This Repo) -> Destination (Marketplace)**
- `PowerShell\` -> `vt-scripts\scripts\PowerShell\`
- `Python\` -> `vt-scripts\scripts\Python\`

*Note: This includes all subdirectories like `Common`, `Windows-Only`, and `Windows-Terminal`, maintaining the exact same structure.*

### 2. Required Skill Files
The Marketplace requires specific files to define the skill for `skills.sh`.

- **`vt-scripts\SKILL.md`**
  This is the core instructions file containing the YAML frontmatter. It teaches the agent how to invoke the local scripts that were copied into its `./scripts/` directory.

### 3. Marketplace README Updates
- The root `README.md` of the `VT-SKILLS-MarketPlace` repository must be updated to include the new skill in its catalog, providing users with the correct `npx skills add voltaire-toledo/skills --skill vt-scripts` command.

---
*Update (2026-08-13)*: The initial sync has been successfully performed. The `PowerShell` and `Python` scripts from `VT-Scripts-Library` have been successfully copied over to `VT-SKILLS-MarketPlace/vt-scripts/scripts/` and the `SKILL.md` instruction file has been generated. This skill is now ready to be committed and pushed to the `voltaire-toledo/skills` GitHub repository for public installation!
