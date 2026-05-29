# claude-dev-toolkit

End-to-end development workflow for Claude Code. Five skills that chain together to take you from "I have a task" to "code is committed":

```
/claude-dev-toolkit:research-codebase  ← find WHERE the code lives
/claude-dev-toolkit:plan-feature       ← define HOW to implement
/claude-dev-toolkit:execute-plan       ← DO IT (sequential or parallel)
/claude-dev-toolkit:list-plans         ← see all plans + status
/claude-dev-toolkit:switch-plan        ← pause one, resume another
```

Supports **multiple plans per project** — work on several features concurrently, pause and resume without losing context.

## Install

### From this repo (development)

```bash
git clone https://github.com/TrangToan/claude-dev-toolkit.git
claude --plugin-dir ./claude-dev-toolkit
```

### From a marketplace (once published)

```bash
/plugin marketplace add TrangToan/claude-dev-toolkit
/plugin install claude-dev-toolkit
```

## Skills

### 1. research-codebase

Research the current codebase to identify files, methods, and tests relevant to a task. Returns a structured report with `file:line` references, execution flow, and suggested next steps.

```
/claude-dev-toolkit:research-codebase users can't reset password — getting 500 error
```

Output:
- Type (Bug / Feature / Enhancement)
- Related files grouped by Core / Tests / Config
- Execution flow description
- Where to start

### 2. plan-feature

Turn the research result into a phased implementation plan with a trackable checklist.

```
/claude-dev-toolkit:plan-feature
```

You can pass extra notes:

```
/claude-dev-toolkit:plan-feature focus on backend changes only
```

Output:
- Overview (type, goal, risk, effort)
- Phases (Setup → Implementation → Testing)
- Risks and dependencies
- Execution checklist with checkboxes

### 3. execute-plan

Execute the plan automatically. Supports two modes:

**Sequential (default, safe):**
```
/claude-dev-toolkit:execute-plan
```
- One task at a time
- Auto-commit after each phase
- Pauses for review between phases
- Zero risk of merge conflicts

**Parallel (faster, opt-in):**
```
/claude-dev-toolkit:execute-plan --parallel
```
- Analyzes which tasks touch disjoint files
- Creates a git worktree per parallel-safe task
- Spawns subagents to work in parallel
- Falls back to sequential for tasks that share files

**Resume after interruption:**
```
/claude-dev-toolkit:execute-plan --phase 3
```

## Full workflow example

```
You: /claude-dev-toolkit:research-codebase add PDF export to reports page

Claude: [returns list of relevant files + execution flow]

You: /claude-dev-toolkit:plan-feature

Claude: [returns 3-phase plan with checklist]

You: /claude-dev-toolkit:execute-plan --parallel

Claude: [analyzes parallelism, asks approval, executes in worktrees,
         commits per phase, pauses for your review at each phase boundary]
```

## Multiple plans per project

Each plan lives in its own directory under `.claude/plans/`:

```
.claude/plans/
├── ACTIVE                       ← slug of the currently active plan
├── add-pdf-export/
│   ├── PLAN.md                  ← the plan content
│   ├── STATE.md                 ← in_progress / paused / completed
│   ├── PROGRESS.md              ← current phase, checklist progress
│   └── HANDOFF.md               ← per-plan hand-off
├── fix-login-bug/
│   └── ...
└── _archive/
    └── old-feature-20260515/    ← completed plans archived with date
```

You can have several plans in different states (one active, several paused) and switch between them freely. Use `/list-plans` to see them all and `/switch-plan <slug>` to swap.

## Hand-off enforcement (built-in)

The plugin ships with a smart Stop hook that prevents you from ending a session mid-plan without writing a hand-off note.

**How it works:**
- `execute-plan` creates `.claude/plans/<slug>/STATE.md` set to `in_progress`
- The Stop hook scans every plan directory; for any plan with state `in_progress` it requires a fresh `HANDOFF.md`
- If HANDOFF.md is missing or older than the latest commit → Stop is blocked until Claude writes it
- Plans with state `paused`, `completed`, or in `_archive/` are not checked
- Projects without `.claude/plans/` are ignored entirely

This means you never lose context between sessions or when juggling multiple plans, even if you forget to ask for a hand-off explicitly.

**To disable** (not recommended), uninstall the plugin or override the Stop hook in your `~/.claude/settings.json`.

## Safety guarantees

- Never uses `--no-verify` to skip hooks
- Never `git reset --hard` without explicit permission
- Never force-pushes
- Stops immediately on test failure (does not edit tests to make them pass)
- Pauses between phases — no autonomous multi-phase runs
- Per-phase commit gives clean rollback points

## Why these three skills?

Each step answers a different question:

| Step             | Question        | Reduces       |
| :--------------- | :-------------- | :------------ |
| research-codebase | WHERE is it?    | Search time   |
| plan-feature     | HOW will I do it? | Surprises mid-implementation |
| execute-plan     | DO IT           | Manual repetition |

Splitting them lets you correct course between steps. The research might surface a file you didn't expect; the plan might reveal a risk; you handle these before any code changes.

## License

MIT
