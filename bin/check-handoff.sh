#!/bin/bash
# Smart hand-off enforcement for claude-dev-toolkit.
# Only blocks the Stop event when an active plan exists without a fresh HANDOFF.md.
# Stays out of the way for sessions that don't use the toolkit.

set -e

PLANS_DIR=".claude/plans"
HANDOFF=".claude/HANDOFF.md"

# Not in a project that uses the toolkit -> noop
if [ ! -d "$PLANS_DIR" ]; then
  exit 0
fi

# Plans directory is empty -> no active plan -> noop
if [ -z "$(ls -A "$PLANS_DIR" 2>/dev/null)" ]; then
  exit 0
fi

# Active plan exists -> check HANDOFF.md
if [ ! -f "$HANDOFF" ]; then
  cat <<EOF
{
  "decision": "block",
  "reason": "An active plan exists in .claude/plans/ but .claude/HANDOFF.md is missing. Before ending the session, create .claude/HANDOFF.md documenting: (1) what was completed, (2) what is in progress, (3) files modified, (4) suggested next steps for resuming. Use the /handoff skill if available, or write it manually."
}
EOF
  exit 0
fi

# HANDOFF.md exists -> check it's fresher than the latest commit
LAST_HANDOFF_MTIME=$(stat -f %m "$HANDOFF" 2>/dev/null || stat -c %Y "$HANDOFF" 2>/dev/null || echo 0)
LAST_COMMIT_TIME=$(git log -1 --format=%ct 2>/dev/null || echo 0)

if [ "$LAST_COMMIT_TIME" -gt "$LAST_HANDOFF_MTIME" ]; then
  cat <<EOF
{
  "decision": "block",
  "reason": "HANDOFF.md is older than the latest commit. Update .claude/HANDOFF.md to reflect the most recent changes before ending the session."
}
EOF
  exit 0
fi

# All checks passed
exit 0
