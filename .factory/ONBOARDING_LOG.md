# Factory Onboarding Log - nanobot

This document captures the process used to onboard nanobot into the FBA
managed factory system. The goal is to document each step so we can
formalize and automate the onboarding workflow for future projects.

## Process Steps (as executed)

### Step 1: Factory Creation (DONE)
- Command: fba create --repo ../nanobot --name nanobot
- Run from: FBA repo directory (where fba CLI is installed)
- Output: factory-nanobot/ directory with config, roles, constitution
- Then: Moved output to .factory/ inside the nanobot repo
- Committed to: factory-bootstrap branch on 85matthew/nanobot

What fba create produced:
- config/factory.yml - project analysis (Python, complexity L, Gemini cascade)
- config/constitution.md - universal governance rules (inherited from FBA)
- config/roles/ - agent role prompts (planner, coder, reviewer, red_team)
- bootstrap.sh - startup script
- docker-compose.yml - container orchestration
- .env.example - environment variable template

What was missing (and why this onboarding process exists):
- No project-specific governance (BYLAWS.md)
- No tactical coder rules (CLAUDE.md)
- No business intelligence / KPI definition
- No .github/workpackages/ directory
- No PR review workflow
- No roadmap or backlog
- No understanding of the project business purpose or architectural constraints

### Step 2: CDO/CTO Analysis (DONE)

The planner (acting as CDO/CTO) analyzed the codebase and produced:

Codebase analysis covered:
- nanobot/ directory structure (14 subsystems)
- providers/registry.py — ProviderSpec pattern, 16 providers, find_by_model/find_gateway helpers
- agent/loop.py — core LLM-tool execution cycle (22KB, largest file)
- channels/ — 12 channel implementations with base class pattern
- config/schema.py — Pydantic v2 config models
- pyproject.toml — dependencies, build system, test config
- tests/ — 16 existing test files covering channels, memory, tools, CLI, cron
- Upstream issues — reviewed 20 most recent open issues on HKUDS/nanobot

Key findings:
- Architecture is plugin-based (registry pattern for providers, tools; base class for channels)
- Bus-based message routing decouples channels from agent loop
- Skills are markdown files loaded at runtime
- Core line count ~4,000 (upstream identity constraint, not enforced in our sandbox)
- Test suite has ~106 tests but sparse coverage of core agent loop

Questions asked to user:
1. Contributing upstream or standalone? — Standalone throwaway sandbox
2. Honor 4,000-line budget? — No, do what we want
3. First improvement priority? — Take real issues from upstream repo

Artifacts produced:
- .factory/config/BYLAWS.md — project-specific strategic governance
- CLAUDE.md — tactical coder rules (commands, architecture map, patterns, pitfalls)

### Step 3: Infrastructure Setup (DONE)

Created:
- .github/workpackages/ directory with WP-001
- CLAUDE.md at repo root
- .factory/config/BYLAWS.md

Not yet created (not needed for manual dispatch):
- PR review workflow (would need to be adapted from FBA template)
- ROADMAP.md (not needed for throwaway sandbox)
- BACKLOG.md (not needed for throwaway sandbox)

### Step 4: First Work Package (READY FOR DISPATCH)

WP-001: Fix Cron Notification Feedback Loop
- Based on upstream issue HKUDS/nanobot#1441
- Bug: cron notifications re-enter agent loop as user messages, causing infinite recursion
- Bounded to agent/loop.py, cron/service.py, bus layer
- Clear acceptance criteria and test strategy
- Manual dispatch required (FBA automation is wired to FBA repo, not nanobot)

Dispatch method: Run Claude Code manually pointed at 85matthew/nanobot, provide WP-001
as the task description along with CLAUDE.md and BYLAWS.md context.

## Key Insight: Type A vs Type B Work

During this onboarding, we identified two fundamentally different kinds of factory work:

Type A — Code improvement (fix bugs, add tests, refactor). The coder reads code and
writes code. Business context is minimal. This is what WP-001 tests.

Type B — Business transformation (AI-enable a dental office, add intelligent agents to
a real estate CRM). The challenge is understanding the business domain, identifying
automation opportunities, designing agent workflows. This requires the CDO/CTO role
and tests whether BYLAWS can encode business rules that guide technical implementation.

Nanobot dogfooding tests Type A. A future project (possibly a fresh FastAPI app with
a business domain) will test Type B. The BYLAWS/CLAUDE.md/Constitution three-layer
model needs to work for both.

## Governance Layer Model

Three-layer governance, each serving a different audience and purpose:

### Layer 1: CONSTITUTION.md (Universal)
- Audience: All agents across all factories
- Content: TDD process, pre-task algorithm, error budgets, review protocol, amendment process, role definitions
- Changes: Rare, requires Level 4 approval, propagates to all factories
- Analogy: The operating system

### Layer 2: BYLAWS.md (Project-Specific Strategic)
- Audience: Planner, CDO/CTO, architects, senior agents
- Content: Project identity and core value proposition, architectural constraints and patterns, business KPIs and success metrics (telemetry targets), domain-specific rules (e.g. banking compliance or code size budget), technology choices and their rationale, plugin/extension patterns, quality gates beyond the constitution
- Changes: When roadmap milestones change or architecture evolves
- Analogy: Corporate bylaws - how THIS company operates within the law

### Layer 3: CLAUDE.md (Tactical)
- Audience: Coders, reviewers, day-to-day agents
- Content: File conventions and import patterns, test commands and framework usage, naming conventions, tool-specific rules (linters, formatters), common pitfalls in this codebase, how-to-add-a-new-X recipes
- Changes: Frequently, as conventions evolve
- Analogy: The team wiki / onboarding doc for new developers

### Business Intelligence Layer (lives in BYLAWS.md)
- Purpose: Define what healthy and successful look like for this project
- For FBA: Time to ship, PR rejection rate, bug escape rate, test coverage
- For nanobot: Response latency, tool execution success rate, channel uptime, memory accuracy, core line count (must stay under 4000)
- For a bank: Transaction success rate, latency p99, fraud detection accuracy, customer satisfaction, regulatory compliance score
- Informs: Telemetry design, reviewer criteria, planner priorities, error budgets

## Roles in Onboarding

### CDO/CTO (new role - currently played by planner)
- Analyzes the existing codebase
- Identifies business purpose and architectural patterns
- Drafts BYLAWS.md
- Asks user clarifying questions about governance preferences
- Produces initial ROADMAP.md
- May be automated in the future via fba onboard command

### User (human)
- Provides business context the CDO cannot infer from code
- Approves or modifies BYLAWS.md
- Sets priorities for the initial roadmap
- Answers governance questions (how strict? what is negotiable?)

### Planner (existing role)
- Takes the approved BYLAWS + ROADMAP and writes work packages
- Operates within the governance framework, does not define it

## Open Questions
- Should BYLAWS.md be a single file or a directory of domain-specific docs?
- How do business KPIs flow into the telemetry system concretely?
- Should the CDO role be a separate LLM session or the same as the planner?
- How much of the CLAUDE.md can be auto-generated from codebase analysis?
- When a new Roadmap milestone is added, what is the formal process for updating BYLAWS?
- What project should we use for Type B (business transformation) testing?
