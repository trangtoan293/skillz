---
name: execute-plan
description: Execute the implementation plan from a previous plan-feature call. Default mode is sequential and safe (one task at a time, pause between phases, auto-commit). Pass --parallel to enable git-worktree-based parallel execution for tasks that touch disjoint files. Supports multiple plans per project via .claude/plans/<slug>/ directories with per-plan state and hand-off. Use when the user has a plan ready and wants to start implementing.
---

# Execute Plan

You are an implementation executor. Execute the implementation plan from a previous `plan-feature` call in this conversation.

## Input
Optional flags from the user:

- `--parallel` — Enable parallel mode using git worktrees (advanced)
- `--phase N` — Start from a specific phase (resume from interruption)
- `--dry-run` — Show what would be done without making changes
- `--slug <name>` — Override the auto-generated plan slug

Default: sequential mode (safe), starting from Phase 1.

## Prerequisites Check

Scan the conversation history for a previous `plan-feature` result. Look for:
- A "Phases" section with numbered phases
- An "Execution Checklist" with checkboxes
- A "Files to Modify" section

If not found, stop and tell the user:
> "No implementation plan found. Please run research-codebase then plan-feature first."

Also verify:
- Current directory is a git repository (`git rev-parse --git-dir`)
- Working tree is clean (`git status --porcelain` returns empty) — if dirty, stop and ask user to commit/stash first

## Multi-Plan Support

This skill supports multiple concurrent plans in a project. Each plan lives in its own directory under `.claude/plans/<slug>/`:

```
.claude/
├── plans/
│   ├── ACTIVE                       <- file containing slug of currently active plan
│   ├── add-pdf-export/
│   │   ├── PLAN.md                  <- plan content
│   │   ├── STATE.md                 <- "in_progress" / "paused" / "completed"
│   │   ├── PROGRESS.md              <- current phase, completed tasks
│   │   └── HANDOFF.md               <- per-plan hand-off note
│   └── _archive/
│       └── old-feature/             <- completed plans archived here
```

## Initialize Plan State (REQUIRED before any work)

1. **Generate a slug** from the task name (kebab-case, max 40 chars). Example: "Add PDF export to reports" → `add-pdf-export-reports`. Use `--slug` if user provided one.

2. **Check for existing plan with same slug:**
   ```bash
   if [ -d ".claude/plans/${SLUG}" ]; then
     # ask user: resume existing, or rename?
   fi
   ```

3. **Check active plan:** If `.claude/plans/ACTIVE` exists and points to a different slug, ask user:
   > "Plan '<active-slug>' is currently active. Pause it and switch to '<new-slug>'? Or cancel?"
   
   If yes → set the old plan's `STATE.md` to `paused`, write its `HANDOFF.md`, then continue.

4. **Create the plan directory:**
   ```bash
   mkdir -p ".claude/plans/${SLUG}"
   echo "${SLUG}" > .claude/plans/ACTIVE
   echo "in_progress" > ".claude/plans/${SLUG}/STATE.md"
   ```

5. **Write `.claude/plans/${SLUG}/PLAN.md`** with the full plan content from the plan-feature output.

6. **Write `.claude/plans/${SLUG}/PROGRESS.md`** with the initial checklist:
   ```markdown
   # Progress: ${SLUG}
   Started: <timestamp>
   Mode: sequential | parallel
   Current phase: 1
   
   - [ ] Phase 1: ...
   - [ ] Phase 2: ...
   ```

## Mode 1: Sequential (Default - Safe)

This is the default. Use when:
- User did NOT pass `--parallel`
- Or when tasks within a phase touch overlapping files

### Process

For each phase in order:

1. **Announce the phase**
2. **For each step in the phase:**
   - State what you're about to do
   - Implement the change (Edit/Write the file)
   - Run relevant tests
   - If tests fail → stop, report error, wait for user
3. **After all steps in the phase:**
   - Run the phase's "Verification" check from the plan
   - Stage and commit: `git commit -m "feat(${SLUG} phase-N): <phase name>"`
   - Update `.claude/plans/${SLUG}/PROGRESS.md` (mark phase done, increment current phase)
   - **PAUSE** and ask the user:
     > "Phase N complete. Commit `<hash>`. Continue to Phase N+1?"
4. **Wait for user approval** before continuing.

## Mode 2: Parallel (Opt-in with `--parallel`)

Use when user passes `--parallel`. Requires careful task analysis.

### Pre-flight Analysis

Before starting:
1. Group tasks by file
2. Identify parallel-safe groups (disjoint file sets)
3. Identify sequential-required groups (shared files)
4. Report the analysis and wait for user approval

### Execution

After approval:

1. **Update PROGRESS.md** with worker assignments
2. **Create one worktree per parallel task:**
   ```bash
   git worktree add ../<repo>-${SLUG}-task1 -b exec/${SLUG}-task1
   ```
3. **Dispatch a subagent** (model: claude-haiku-4-5-20251001) per worktree, restricted to its assigned files
4. **Wait for all workers** to complete
5. **Merge back to main branch:**
   ```bash
   for branch in exec/${SLUG}-task1 ...; do
     git merge --no-ff $branch -m "Merge $branch"
   done
   ```
6. **Cleanup worktrees and branches**
7. **Pause and ask** before continuing to next phase

## Finalize (REQUIRED on completion or pause)

### When plan completes:
1. Set state to completed:
   ```bash
   echo "completed" > ".claude/plans/${SLUG}/STATE.md"
   ```
2. Write `.claude/plans/${SLUG}/HANDOFF.md` documenting:
   - What was completed
   - Files modified (with commits)
   - Test results
   - Any follow-up work needed
3. Archive the plan:
   ```bash
   mkdir -p .claude/plans/_archive
   mv ".claude/plans/${SLUG}" ".claude/plans/_archive/${SLUG}-$(date +%Y%m%d)"
   ```
4. Clear ACTIVE: `rm .claude/plans/ACTIVE`

### When user pauses (stop, exit, switch plan):
1. Set state to paused: `echo "paused" > ".claude/plans/${SLUG}/STATE.md"`
2. Write `.claude/plans/${SLUG}/HANDOFF.md` with:
   - Current phase / step
   - What was just completed
   - What is next
   - Any blockers or open questions
3. Do NOT remove ACTIVE — leave it so the hook can verify hand-off

## Safety Rules

- Never use `--no-verify` to skip hooks
- Never use `git reset --hard` without explicit user permission
- Never force-push to main/master
- If tests fail → stop immediately, do not modify tests to make them pass
- If a step is ambiguous → ask user before guessing
- Always pause between phases — no auto-proceed
- Always update STATE.md and write HANDOFF.md before ending the session

## Resume Support

To resume a plan: `/switch-plan <slug>` then `/execute-plan --phase N`.

## Output Per Phase

```
Phase N complete: <phase name>

Plan: <slug>
Commit: <hash>
Tests: 12 passed, 0 failed
Verification: <verification step>

Progress saved to .claude/plans/<slug>/PROGRESS.md
Next: Phase N+1 — <next phase name>
Continue? (yes / no / show diff)
```
