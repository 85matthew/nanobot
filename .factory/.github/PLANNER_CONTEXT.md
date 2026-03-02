# Planner Agent Context

**Factory:** nanobot
**Repo:** (set after git init)
**Tests:** (run `python -m pytest tests/ -v` to check)
**Constitution version:** 2.3

## Purpose

This factory uses a TDD coding loop with AI agents (planner, coder, reviewer)
coordinated through a state machine, with telemetry and auto-adjustment.

## Completed Work

(none yet — this is a new factory)

## Current Phase

Phase 1 (human-orchestrated). See ROADMAP.md for full phase plan.

## Planner Notes

- Work packages live in `.github/workpackages/`
- Completed packages move to `.github/workpackages/completed/`
- Use `fba dispatch --dry-run` to preview the work queue
- Use `fba dispatch --wp WP-NNN` to assign a specific package

## Work Package Template

```markdown
# WP-NNN: Title

**Status:** READY
**Priority:** HIGH | MEDIUM | LOW
**Assigned to:** Claude Code (Sonnet)
**Dependencies:** (none, or WP-XXX)

## Context
(why this work is needed)

## Tasks
### 1. Task description
(details)

## Files to Create/Modify
- file.py (reason)

## Files NOT to Touch
- other.py (reason)

## Verification Checklist
- [ ] python -m pytest tests/ -v — all tests pass
- [ ] (task-specific checks)
```
