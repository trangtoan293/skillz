---
name: list-plans
description: List all implementation plans in the current project, showing their status (active/in_progress/paused/completed), current phase, and last update time. Use to get an overview when working on multiple plans concurrently, or to find a plan to resume.
---

# List Plans

Show all implementation plans tracked in `.claude/plans/` for the current project.

## Steps

1. **Check for plans directory:**
   ```bash
   if [ ! -d ".claude/plans" ]; then
     echo "No plans tracked in this project yet. Run /research-codebase + /plan-feature + /execute-plan to start one."
     exit 0
   fi
   ```

2. **Read ACTIVE pointer:**
   ```bash
   ACTIVE=$(cat .claude/plans/ACTIVE 2>/dev/null || echo "")
   ```

3. **For each plan directory under `.claude/plans/` (excluding `_archive` and `ACTIVE`):**
   - Read `STATE.md` for status
   - Read `PROGRESS.md` for current phase / progress
   - Get mtime of the directory

4. **For each plan in `.claude/plans/_archive/`:**
   - Read STATE.md (should be "completed")
   - Get archive date from directory name

## Output Format

```
# Plans in this project

## Active
- add-pdf-export
  Status: in_progress
  Phase: 2 of 3
  Started: 2026-05-28
  Last update: 2 hours ago

## Paused
- fix-login-bug
  Status: paused
  Phase: 1 of 2 (Phase 1 complete, Phase 2 not started)
  Started: 2026-05-25
  Last update: 3 days ago
  Resume: /switch-plan fix-login-bug

## Completed / Archived
- old-refactor (archived 2026-05-20)
- initial-setup (archived 2026-05-15)

## Summary
- Active: 1
- Paused: 1
- Completed: 2

To switch to another plan: /switch-plan <slug>
To start a new plan: /research-codebase <task>
```

## Rules

- Sort active first, then paused, then archived
- If no ACTIVE file exists but some plans are in_progress → flag this as an inconsistency
- Show resume command for paused plans
- Hide details of archived plans unless user passes `--all`
