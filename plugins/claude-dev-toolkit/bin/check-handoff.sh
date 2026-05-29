#!/bin/bash
# Smart hand-off enforcement for claude-dev-toolkit.
# Checks each in_progress plan under .claude/plans/<slug>/ and blocks Stop
# if any of them is missing a fresh HANDOFF.md.
# Stays out of the way for sessions/projects that don't use the toolkit.

set -e

PLANS_DIR=".claude/plans"

# Not a toolkit project -> noop
if [ ! -d "$PLANS_DIR" ]; then
  exit 0
fi

MISSING=()
STALE=()

for plan_dir in "$PLANS_DIR"/*/; do
  # Skip archive directory
  case "$plan_dir" in
    *"/_archive/"*) continue ;;
  esac

  # Skip non-directories and special files
  [ -d "$plan_dir" ] || continue

  STATE_FILE="${plan_dir}STATE.md"
  HANDOFF_FILE="${plan_dir}HANDOFF.md"
  SLUG=$(basename "$plan_dir")

  # No STATE.md -> skip (probably not a plan dir)
  [ -f "$STATE_FILE" ] || continue

  STATE=$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')

  # Only enforce for in_progress plans
  if [ "$STATE" != "in_progress" ]; then
    continue
  fi

  # Check HANDOFF.md exists
  if [ ! -f "$HANDOFF_FILE" ]; then
    MISSING+=("$SLUG")
    continue
  fi

  # Check HANDOFF.md is fresher than the latest commit
  LAST_HANDOFF_MTIME=$(stat -f %m "$HANDOFF_FILE" 2>/dev/null || stat -c %Y "$HANDOFF_FILE" 2>/dev/null || echo 0)
  LAST_COMMIT_TIME=$(git log -1 --format=%ct 2>/dev/null || echo 0)

  if [ "$LAST_COMMIT_TIME" -gt "$LAST_HANDOFF_MTIME" ]; then
    STALE+=("$SLUG")
  fi
done

# Nothing to block
if [ ${#MISSING[@]} -eq 0 ] && [ ${#STALE[@]} -eq 0 ]; then
  exit 0
fi

# Build the reason message
REASON="Cannot end session — hand-off issues with in_progress plans:"

if [ ${#MISSING[@]} -gt 0 ]; then
  REASON="$REASON  Missing HANDOFF.md in plans: $(printf '%s, ' "${MISSING[@]}" | sed 's/, $//')."
fi

if [ ${#STALE[@]} -gt 0 ]; then
  REASON="$REASON  HANDOFF.md is older than latest commit in plans: $(printf '%s, ' "${STALE[@]}" | sed 's/, $//')."
fi

REASON="$REASON  Write/update .claude/plans/<slug>/HANDOFF.md for each affected plan documenting: current phase, what was completed, what is next, and any blockers. Use the handoff skill if available."

# Output JSON to block Stop
printf '{"decision": "block", "reason": "%s"}\n' "$REASON"
exit 0
