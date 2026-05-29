---
name: execute-plan
description: Execute the implementation plan from a previous plan-feature call. Default mode is sequential and safe (one task at a time, pause between phases, auto-commit). Pass --parallel to enable git-worktree-based parallel execution for tasks that touch disjoint files. Use when the user has a plan ready and wants to start implementing.
---

# Execute Plan

You are an implementation executor. Execute the implementation plan from a previous `plan-feature` call in this conversation.

## Input
Optional flags from the user:

Supported flags:
- `--parallel` — Enable parallel mode using git worktrees (advanced)
- `--phase N` — Start from a specific phase (resume from interruption)
- `--dry-run` — Show what would be done without making changes

Default: sequential mode (safe), starting from Phase 1.

## Prerequisites Check

Scan the conversation history for a previous `/plan-feature` result. Look for:
- A "Phases" section with numbered phases
- An "Execution Checklist" with checkboxes
- A "Files to Modify" section

If not found, stop and tell the user:
> "No implementation plan found. Please run `/research-codebase <task>` then `/plan-feature` first."

Also verify:
- Current directory is a git repository (`git rev-parse --git-dir`)
- Working tree is clean (`git status --porcelain` returns empty) — if dirty, stop and ask user to commit/stash first

## Initialize Plan State (REQUIRED before any work)

Before starting Phase 1, create the plan state directory. This is the signal the hand-off enforcement hook uses to detect an active plan:

```bash
TASK_SLUG="<short-kebab-case-from-task-name>"
mkdir -p ".claude/plans/${TASK_SLUG}"
```

Write `.claude/plans/${TASK_SLUG}/PLAN.md` with the full plan, current phase, and progress. Update it as phases complete.

## Finalize (REQUIRED at end of execution)

When all phases are done (or the user stops execution), write/update `.claude/HANDOFF.md` documenting:
- What was completed
- What is still in progress (if any)
- Files modified
- Suggested next steps

If the `handoff` skill is available, call it instead of writing manually.

## Mode 1: Sequential (Default - Safe)

This is the default. Use when:
- User did NOT pass `--parallel`
- Or when tasks within a phase touch overlapping files

### Process

For each phase in order:

1. **Announce the phase**
   > "Starting Phase N: [name]"

2. **For each step in the phase:**
   - State what you're about to do
   - Implement the change (Edit/Write the file)
   - Run relevant tests if any (`pytest tests/test_xxx.py`, `npm test`, etc.)
   - If tests fail → stop, report error, wait for user

3. **After all steps in the phase:**
   - Run the phase's "Verification" check from the plan
   - Stage and commit:
     ```bash
     git add <changed files>
     git commit -m "feat(phase-N): <phase name>"
     ```
   - Update the checklist in the conversation — mark Phase N items as `[x]`
   - **PAUSE and ask the user:**
     > "Phase N complete. Changes committed as `<commit-hash>`. Review the diff with `git show HEAD`. Continue to Phase N+1? (yes/no/details)"

4. **Wait for user approval before continuing.** Do NOT auto-proceed to the next phase.

## Mode 2: Parallel (Opt-in with `--parallel`)

Use when user passes `--parallel`. Requires careful task analysis.

### Pre-flight Analysis

Before starting, analyze the plan:

1. **Group tasks by file** — for each task, list which files it modifies
2. **Identify parallel-safe groups** — tasks within a phase that touch **disjoint** sets of files
3. **Identify sequential-required groups** — tasks that share files must run sequentially
4. **Report the analysis** to the user:

   ```
   Phase 2 Analysis:
     Parallel-safe (3 agents):
       - Task 2.1 → src/pdf_export.py
       - Task 2.2 → src/api/routes.py
       - Task 2.3 → frontend/Button.tsx
     Sequential-required (1 agent):
       - Task 2.4 → modifies multiple files used above
   
   Proceed with parallel execution? (yes/no)
   ```

5. **Wait for user approval** before spawning anything.

### Execution

After approval:

1. **Create state file** at `.claude/plans/<task-slug>/STATE.md`:
   ```markdown
   # Plan State
   ## Phase 2 (parallel)
   - [⏳] 2.1 — owner: worker-1, branch: exec/phase2-task1, worktree: ../<repo>-phase2-task1
   - [⏳] 2.2 — owner: worker-2, branch: exec/phase2-task2, worktree: ../<repo>-phase2-task2
   - [⏳] 2.3 — owner: worker-3, branch: exec/phase2-task3, worktree: ../<repo>-phase2-task3
   ```

2. **Create one worktree per parallel task:**
   ```bash
   git worktree add ../<repo>-phase2-task1 -b exec/phase2-task1
   git worktree add ../<repo>-phase2-task2 -b exec/phase2-task2
   git worktree add ../<repo>-phase2-task3 -b exec/phase2-task3
   ```

3. **For each worktree, dispatch a subagent** (using the Agent tool with `claude-haiku-4-5-20251001`):
   - Subagent prompt: "You are worker-N. Working directory: `<worktree-path>`. Task: [task description]. Files: [allowed files]. Implement, test, commit on branch `exec/phase2-taskN`. Report when done."
   - Restrict each worker to modifying only its assigned files

4. **Wait for all workers in the phase to complete**

5. **Merge back to main:**
   ```bash
   git checkout main  # or the branch you started from
   for branch in exec/phase2-task1 exec/phase2-task2 exec/phase2-task3; do
     git merge --no-ff $branch -m "Merge $branch"
   done
   ```

6. **Handle conflicts** if any (should be rare since files were disjoint):
   - Report conflict to user
   - Pause and let user resolve manually
   - Do NOT auto-resolve

7. **Cleanup worktrees:**
   ```bash
   git worktree remove ../<repo>-phase2-task1
   git worktree remove ../<repo>-phase2-task2
   git worktree remove ../<repo>-phase2-task3
   git branch -d exec/phase2-task1 exec/phase2-task2 exec/phase2-task3
   ```

8. **Run phase verification** (tests, build, etc.)

9. **Pause and ask user** before continuing to next phase (same as sequential mode)

## Safety Rules (BOTH modes)

- **Never use `--no-verify`** to skip hooks
- **Never use `git reset --hard`** without explicit user permission
- **Never force-push** to main/master
- **If tests fail** → stop immediately, do not "fix" by changing the tests
- **If a step is ambiguous** → ask user before guessing
- **If file doesn't exist** that the plan references → stop and report (plan may be stale)
- **Always pause between phases** — no auto-proceed across phase boundaries

## Resume Support

If interrupted (user stops, error, etc.):
- State is preserved in:
  - Git commits (per-phase)
  - `.claude/plans/<task-slug>/STATE.md` (in parallel mode)
- User can resume with `/execute-plan --phase N` to skip already-done phases

## Output Per Phase

After each phase:

```
✅ Phase N complete: [phase name]

Changes:
- src/file_a.py — added X function
- tests/test_a.py — added 2 test cases

Commit: <hash> "feat(phase-N): <name>"

Tests: 12 passed, 0 failed
Verification: ✅ <verification step from plan>

Next: Phase N+1 — [next phase name]
Continue? (yes / no / show diff)
```
