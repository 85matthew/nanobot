# Nanobot Project Bylaws
# Version: 0.1 (sandbox/dogfood)

## Project Identity

Nanobot is an ultra-lightweight personal AI assistant framework (~4,000 lines core).
This fork (85matthew/nanobot) is a sandbox for testing the FBA factory onboarding
process. Changes here are throwaway — we are not contributing upstream.

## Architectural Constraints

These constraints exist in the upstream project and we honor them for realistic testing:

1. Plugin pattern is king. Providers use ProviderSpec in a registry tuple. Channels
   implement a base class. Tools follow a registration pattern. New features should
   extend via these patterns, not modify core.

2. Bus-based message routing. Channels publish to the bus, the agent loop consumes
   from the bus. Do not create direct channel-to-agent coupling.

3. LiteLLM is the provider abstraction layer. All LLM calls route through LiteLLM
   unless the provider is marked is_direct (CustomProvider) or is_oauth (Codex).

4. Skills are markdown files read at runtime. The agent discovers and loads skills
   from the workspace skills directory.

## Business Intelligence (Sandbox Metrics)

Since this is a test sandbox, our KPIs are about the factory process, not nanobot itself:

- Can a coder navigate this unfamiliar codebase with only CLAUDE.md and BYLAWS.md?
- Does the WP provide enough context for a correct implementation?
- Does the reviewer catch real issues vs false positives?
- How many rework cycles before merge?

## Test Requirements

- All existing tests must pass before and after changes (currently ~106 tests)
- New code must include tests (constitution TDD requirement applies)
- Test command: pytest tests/ (asyncio_mode = auto)
- Matrix channel tests may be skipped (requires optional matrix dependencies)

## Domain Rules

- Cron jobs must not create feedback loops (outbound notifications must not
  re-enter the agent loop as inbound user messages)
- Provider registry order matters — it controls match priority and fallback
- Channel implementations must handle graceful disconnection and reconnection
- Session history must be sanitized before sending to providers to prevent
  persistent 400 errors from contaminated messages
