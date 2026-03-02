# CLAUDE.md — Tactical Rules for Nanobot Development

## Project Overview

Nanobot is a lightweight AI assistant framework. Core code lives in nanobot/.
Tests live in tests/. Config schema is in nanobot/config/schema.py.

## Commands

Run tests: pytest tests/
Run tests (verbose): pytest tests/ -v
Run single test file: pytest tests/test_cron_service.py -v
Lint: ruff check nanobot/
Format check: ruff format --check nanobot/

## Architecture Quick Reference

nanobot/
  agent/           # Core agent loop, context building, memory, tools, subagents
    loop.py        # Main LLM-tool execution cycle (largest core file)
    context.py     # System prompt and context assembly
    memory.py      # Memory consolidation and management
    skills.py      # Skill loading and discovery
    subagent.py    # Sub-agent spawning
    tools/         # Tool implementations (filesystem, shell, web, mcp, cron, message)
  bus/             # Event bus for channel-to-agent message routing
  channels/        # Chat platform integrations (telegram, discord, slack, etc.)
    base.py        # Channel base class — all channels implement this
    manager.py     # Channel lifecycle and startup orchestration
  cli/             # CLI commands (typer-based)
  config/          # Configuration loading and schema
    schema.py      # Pydantic models for all config (THE source of truth for config shape)
    loader.py      # YAML config file loading
  cron/            # Scheduled job execution
  heartbeat/       # Periodic health check agent
  providers/       # LLM provider abstraction
    registry.py    # ProviderSpec definitions — THE source of truth for providers
    base.py        # LLMResponse dataclass and base provider interface
    litellm_provider.py  # Main provider (routes through LiteLLM)
    custom_provider.py   # Direct OpenAI-compatible endpoint
  session/         # Conversation session management and history
  skills/          # Built-in skills (markdown files loaded at runtime)
  templates/       # System prompt templates
  utils/           # Shared utilities

## Key Patterns

Adding a new provider:
  1. Add ProviderSpec to PROVIDERS tuple in nanobot/providers/registry.py
  2. Add config field to ProvidersConfig in nanobot/config/schema.py
  That is it. Env vars, prefixing, matching, status display all derive from the spec.

Adding a new channel:
  1. Create nanobot/channels/yourplatform.py implementing the base channel interface
  2. Add config model to schema.py
  3. Register in channels/manager.py

Adding a new tool:
  1. Create tool in nanobot/agent/tools/
  2. Register in nanobot/agent/tools/registry.py

## Conventions

- Python 3.11+
- Pydantic v2 for config models
- Async throughout (asyncio)
- pytest with pytest-asyncio (asyncio_mode = auto)
- ruff for linting (line-length 100, select E/F/I/N/W)
- Loguru for logging
- Type hints required on all function signatures
- Frozen dataclasses for immutable data (ProviderSpec, LLMResponse)

## Common Pitfalls

- Provider registry order matters — gateways first, then standard, then local
- Channel tests may need mocking of external APIs (Telegram, Discord SDKs)
- Matrix tests require optional dependencies and are often skipped
- The agent loop processes messages from both users AND internal systems (cron, heartbeat).
  Internal messages must be distinguishable from user messages to prevent feedback loops.
- Session history can become contaminated with malformed messages (content=None on
  assistant messages with tool_calls). Always sanitize before sending to providers.
- LiteLLM has its own message key filtering. Check _ALLOWED_MSG_KEYS if fields are
  being silently dropped.
