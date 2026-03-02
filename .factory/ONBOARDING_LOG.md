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

### Step 2: CDO/CTO Analysis (IN PROGRESS)

The planner (acting as CDO/CTO) analyzes the existing codebase to understand:
- What is this project core value proposition?
- What are its architectural patterns and constraints?
- What business metrics define success?
- What governance rules should be project-specific vs inherited?

This analysis produces:
- BYLAWS.md - project-specific strategic rules
- Business KPIs - what telemetry should track
- CLAUDE.md - tactical rules for coders
- Questions for the user - things the CDO cannot determine from code alone

### Step 3: Infrastructure Setup (PENDING)
- Create .github/workpackages/ directory
- Create PR review workflow (adapted from FBA template)
- Create ROADMAP.md
- Create BACKLOG.md

### Step 4: First Work Package (PENDING)
- Write and dispatch a bounded WP to validate the pipeline works
- Coder executes against nanobot codebase
- Reviewer checks the PR
- Validate end-to-end

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
