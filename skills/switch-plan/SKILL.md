---
name: switch-plan
description: Switch the active plan in a project that has multiple plans. Pauses the currently active plan (writing its HANDOFF.md first), then activates the target plan and loads its state so work can continue. Use when interrupting one plan to work on another, or resuming a previously paused plan.
---

# Switch Plan

Switch the currently active plan to a different one. Handles pause/resume safely.

## Input
The target plan slug: $ARGUMENTS

If no slug provided, list available plans and ask user to pick.

## Steps

### 1. Validate target

```bash
TARGET="$ARGUMENTS"

if [ -z "$TARGET" ]; then
  # Show list-plans output and ask user to pick
  exit 0
fi

if [ ! -d ".claude/plans/${TARGET}" ]; then
  # Check archive
  if [ -d ".claude/plans/_archive/${TARGET}" ]; then
    echo "Plan '${TARGET}' is in the archive. Unarchive it first? (move back to .claude/plans/)"
    exit 0
  fi
  echo "Plan '${TARGET}' not found. Run /list-plans to see available plans."
  exit 0
fi
```

### 2. Pause the currently active plan (if any)

```bash
ACTIVE=$(cat .claude/plans/ACTIVE 2>/dev/null || echo "")

if [ -n "$ACTIVE" ] && [ "$ACTIVE" != "$TARGET" ]; then
  # Write HANDOFF.md for the active plan before pausing
  echo "Writing hand-off for '${ACTIVE}' before switching..."
  # (write .claude/plans/${ACTIVE}/HANDOFF.md with current progress)
  
  echo "paused" > ".claude/plans/${ACTIVE}/STATE.md"
fi
```

The HANDOFF.md should capture:
- Current phase / step we were on
- What was just completed
- What is next
- Files modified in the session
- Any blockers or open questions

### 3. Activate the target plan

```bash
echo "${TARGET}" > .claude/plans/ACTIVE
echo "in_progress" > ".claude/plans/${TARGET}/STATE.md"
```

### 4. Load context from target plan

Read these files to brief Claude (and the user) on the resumed work:
- `.claude/plans/${TARGET}/PLAN.md` — the original plan
- `.claude/plans/${TARGET}/PROGRESS.md` — where we left off
- `.claude/plans/${TARGET}/HANDOFF.md` — last hand-off note

### 5. Report and ask what to do next

```
Switched to plan: ${TARGET}

Previous plan (${ACTIVE}) → paused (hand-off written)

Resuming context:
  Phase: 2 of 3 (Phase 1 complete, Phase 2 in progress)
  Last completed: Added PDF exporter class
  Next step: Wire up API endpoint in src/api/routes.py
  Files touched so far: 3
  
Hand-off from last session:
  <quote first 5 lines of HANDOFF.md>

Ready to continue. Use /execute-plan --phase 2 to resume execution.
```

## Rules

- Always write HANDOFF.md for the outgoing active plan before switching
- Never lose context — if HANDOFF.md write fails, abort the switch
- If target plan was already active → noop with a friendly message
- If target plan's state was `completed` → ask user to confirm reopening
