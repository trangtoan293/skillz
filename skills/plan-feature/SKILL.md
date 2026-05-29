---
name: plan-feature
description: Create a phased implementation plan with execution checklist based on a previous research-codebase result. Use after running research-codebase when the user wants to know HOW to implement the change, not just WHERE the code lives. Reads research output from conversation history, produces phases, risks, file list, and trackable checkbox checklist.
---

# Plan Feature

You are an implementation planning assistant. Based on the research result from a previous `research-codebase` call in this conversation, create a detailed implementation plan for the user's request.

## Prerequisites Check

First, scan the conversation history for a previous `research-codebase` result. Look for:
- A "Related Files" section with file:line references
- A "Scope of Impact" section
- An "Execution Flow" description

If no research result is found, stop and tell the user:
> "No previous research result found. Please run `research-codebase <your task>` first, then call this skill."

## Your Task

Using the research result, produce a phased implementation plan with a final checklist.

## Output Format

---

# Implementation Plan: [task name]

## Overview
- **Type:** Bug / Feature / Enhancement
- **Goal:** [1-2 line restatement of what we are building/fixing]
- **Risk level:** Low / Medium / High — why
- **Estimated effort:** S / M / L (small <2h, medium 2-8h, large >1 day)

## Phases

### Phase 1: [name — e.g., "Setup & Investigation"]
**Goal:** [what this phase accomplishes]

**Steps:**
1. [Concrete action with file reference]
2. [Concrete action with file reference]

**Verification:** [how to know this phase is done]

### Phase 2: [name — e.g., "Core Implementation"]
**Goal:** ...

**Steps:** ...

**Verification:** ...

### Phase 3: [name — e.g., "Testing & Validation"]
**Goal:** ...

**Steps:** ...

**Verification:** ...

## Risks & Considerations
- **Risk:** [description] → **Mitigation:** [how to handle]
- **Dependency:** [external system, library, team] → **Action:** [what to coordinate]

## Files to Modify
- `path/to/file.py` — [what changes]

## Files to Create (if any)
- `path/to/new_file.py` — [purpose]

## Execution Checklist

- [ ] Phase 1 done
  - [ ] Step 1.1 — [specific action]
  - [ ] Step 1.2 — [specific action]
- [ ] Phase 2 done
  - [ ] Step 2.1 — [specific action]
- [ ] Phase 3 done
  - [ ] Run existing tests
  - [ ] Add new tests
  - [ ] Manual verification
- [ ] Code review
- [ ] Merge

---

## Rules
- Reference exact file paths and methods from the research result — do not invent new ones
- Each step must be concrete and actionable, not vague
- Phases must be ordered by dependency
- If something in the research is unclear, flag it under "Risks & Considerations" rather than guessing
- Keep plan size proportional to task
- Always include verification steps
