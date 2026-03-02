# BYLAWS — nanobot-ai

> Project-specific governance. Supplements the universal CONSTITUTION.md.
> Approved by: Factory Bootstrap Agent | Date: 2026-03-02

---

## 1. Project Identity

**Name:** nanobot-ai
**Version:** 0.1.4.post3
**License:** MIT
**One-liner:** A lightweight personal AI assistant framework (~4K core LOC) with multi-channel chat integration and pluggable LLM providers.

### Core Value Proposition

Nanobot delivers a production-grade AI agent in a fraction of the code of comparable frameworks. It connects to 10 chat platforms and 16+ LLM providers through a clean async message bus architecture. The design philosophy is radical simplicity: every feature must justify its existence against a 4K-line core budget.

### Non-Goals

- Nanobot is NOT a general-purpose orchestration framework (no DAGs, no workflows).
- It does NOT aim to replace enterprise chatbot platforms with admin UIs.
- It does NOT provide its own model hosting or fine-tuning pipeline.

---

## 2. Architectural Constraints

### 2.1 Message Bus Architecture (Mandatory)

All communication between channels and the agent loop flows through `MessageBus` (async queues). Direct coupling between a channel and the agent loop is prohibited.

```
Channel → InboundMessage → MessageBus → AgentLoop → OutboundMessage → MessageBus → Channel
```

### 2.2 Provider Abstraction (Mandatory)

All LLM calls go through the `LLMProvider` abstract base class. No channel, tool, or agent code may call an LLM API directly. The `ProviderSpec` registry in `providers/registry.py` is the single source of truth for provider metadata.

### 2.3 Tool Contract (Mandatory)

Every tool MUST:
- Extend `Tool` ABC from `agent/tools/base.py`
- Implement `name`, `description`, `parameters` (JSON Schema), and `execute(**kwargs) -> str`
- Be registered via `ToolRegistry` — no ad-hoc tool invocation
- Return string results (the agent loop handles serialization)

### 2.4 Channel Contract (Mandatory)

Every channel MUST:
- Extend `BaseChannel` from `channels/base.py`
- Implement `start()`, `stop()`, `send(OutboundMessage)`
- Use `_handle_message()` to publish to the bus (never bypass `is_allowed()`)
- Be registered in `ChannelManager`

### 2.5 Append-Only Sessions (Mandatory)

Session history is JSONL append-only. This is a deliberate design for LLM prompt caching efficiency. Never mutate or reorder existing session messages. Consolidation (archival to MEMORY.md/HISTORY.md) is the only mechanism for pruning.

### 2.6 Workspace Isolation

All agent-generated files, memory, and sessions are scoped to the workspace directory (`~/.nanobot/workspace` by default). Tools that access the filesystem must respect `restrict_to_workspace` when enabled.

### 2.7 Async-First

The entire runtime is `asyncio`-based. Blocking I/O in any channel, tool, or provider code is prohibited. Use `httpx` (not `requests`), `asyncio.Lock` (not `threading.Lock`), etc.

---

## 3. Technology Choices & Rationale

| Technology | Purpose | Rationale |
|---|---|---|
| Python 3.11+ | Core runtime | Async/await maturity, ecosystem breadth, target audience familiarity |
| LiteLLM | LLM routing | 40+ provider support with single interface; avoids per-provider SDKs |
| Pydantic v2 | Config & validation | Schema enforcement with camelCase/snake_case alias support |
| Typer + Rich | CLI | Interactive REPL with markdown rendering; low-overhead |
| loguru | Logging | Structured logging with zero-config; rotation support |
| pytest + pytest-asyncio | Testing | Native async test support; auto mode for minimal boilerplate |
| ruff | Linting | Fast, opinionated; replaces flake8+isort+pycodestyle |
| httpx | HTTP client | Async-native; replaces requests for all HTTP calls |
| croniter | Scheduling | Standard cron expression parsing; no daemon dependency |
| MCP (1.26+) | Tool extensibility | Model Context Protocol for connecting external tool servers |
| TypeScript/Node.js | WhatsApp bridge | Baileys library (WhatsApp Web API) is JS-only; isolated process |

### Dependency Policy

- Pin major versions (`>=X.Y,<(X+1).0.0`) to prevent breaking changes.
- Matrix E2EE support is an optional dependency (`pip install nanobot-ai[matrix]`).
- Dev dependencies (pytest, ruff) are in `[project.optional-dependencies.dev]`.

---

## 4. Business KPIs & Success Metrics

| KPI | Target | Measurement |
|---|---|---|
| Core LOC | < 5,000 lines | `agent/`, `bus/`, `config/`, `cron/`, `heartbeat/`, `session/`, `utils/` |
| Channel LOC per adapter | < 800 lines (median) | Individual channel `.py` files |
| Test coverage (core) | > 80% statement coverage | `pytest --cov=nanobot.agent --cov=nanobot.bus --cov=nanobot.config` |
| LLM call latency (p95) | < 30s for tool-loop completion | Measured at `_run_agent_loop` exit |
| Zero-config startup | User can `nanobot agent` with only an API key env var | Manual test |
| Channel integration time | New channel < 1 day for experienced dev | Measured by WP completion |

---

## 5. Domain-Specific Rules

### 5.1 LLM Response Handling

- Always call `_strip_think()` on response content before using it. Some models embed `<think>` blocks.
- Distinguish `finish_reason == "error"` from normal stops. Error responses must NOT be persisted to session history (see issue #1303).
- Preserve `reasoning_content` and `thinking_blocks` in assistant messages for models that support extended thinking.

### 5.2 Provider Registry Additions

To add a new LLM provider:
1. Add a `ProviderSpec` entry to the `PROVIDERS` tuple in `providers/registry.py`.
2. If the provider uses standard OpenAI-compatible API: set `litellm_prefix` appropriately and use `LiteLLMProvider`.
3. If the provider needs custom logic: create a new provider class extending `LLMProvider`.
4. Add the provider's config field to `ProvidersConfig` in `config/schema.py`.
5. Test with at least one model from that provider.

### 5.3 Channel Message Format

- Channels receive platform-native messages and normalize to `InboundMessage(channel, sender_id, chat_id, content, media, metadata)`.
- Channels receive `OutboundMessage` and format to platform-native format.
- Media attachments are URL strings (base64 data URIs for inline images).
- `metadata` is a dict for channel-specific data (e.g., `message_id` for reply threading).

### 5.4 Memory Consolidation

- Triggered when unconsolidated messages >= `memory_window` (default 100).
- Uses the LLM itself to summarize old messages into MEMORY.md (facts) and HISTORY.md (timestamped log).
- Consolidation runs as a background task under a per-session lock.
- The `/new` command forces immediate consolidation before clearing the session.

---

## 6. Plugin & Extension Patterns

### 6.1 Adding a New Tool

1. Create `nanobot/agent/tools/your_tool.py`
2. Extend `Tool` ABC
3. Register in `AgentLoop._register_default_tools()` (or dynamically via MCP)
4. Add tests in `tests/test_your_tool.py`

### 6.2 Adding a New Channel

1. Create `nanobot/channels/your_channel.py`
2. Extend `BaseChannel`
3. Add config dataclass to `config/schema.py` under `ChannelsConfig`
4. Register in `ChannelManager` (in `channels/manager.py`)
5. Add tests in `tests/test_your_channel.py`

### 6.3 Adding a New Skill

1. Create `nanobot/skills/your-skill/SKILL.md`
2. Follow the skill format (name, description, triggers, instructions)
3. Skills are loaded by `SkillsLoader` from the skills directory
4. Custom user skills go in `workspace/skills/`

### 6.4 MCP Server Integration

1. Add server config to `tools.mcpServers` in config.json
2. Supports `stdio` and `http` transport types
3. Tools are auto-discovered and registered at first message

---

## 7. Quality Gates (Beyond Constitution)

### 7.1 Pre-Merge Checklist

- [ ] `ruff check nanobot/` passes with zero warnings
- [ ] `pytest tests/` passes (asyncio_mode=auto)
- [ ] No new dependencies added without rationale in commit message
- [ ] Core LOC budget not exceeded (run `bash core_agent_lines.sh`)
- [ ] Channel implementations include `allow_from` permission checks
- [ ] All tool `execute()` methods return `str`, not arbitrary types

### 7.2 Prohibited Patterns

- **No blocking I/O** in async code paths. Use `asyncio.to_thread()` if unavoidable.
- **No direct LLM API calls** outside the provider layer.
- **No mutable global state.** Use dependency injection via constructor parameters.
- **No `import *`** anywhere.
- **No hardcoded API keys or secrets.** Use env vars or config.json.

### 7.3 Ruff Configuration

```toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W"]
ignore = ["E501"]
```

Line length is 100 characters. E501 (line too long) is ignored because some tool descriptions and docstrings naturally exceed it.

---

## 8. Amendment Process

These bylaws can be amended by:
1. Opening a PR with proposed changes to this file.
2. Providing rationale tied to a specific issue, architectural decision, or observed failure.
3. Approval by the project owner or designated CDO/CTO agent.

Amendments that relax quality gates or architectural constraints require explicit justification showing why the constraint is no longer serving the project.
