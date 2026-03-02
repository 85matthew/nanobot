# BYLAWS.md — Nanobot Project Governance

**Project:** nanobot-ai (fork of HKUDS/nanobot)
**Type:** Lightweight personal AI assistant framework
**License:** MIT
**Python:** >=3.11

---

## 1. Project Identity & Value Proposition

Nanobot is a minimal, single-binary AI assistant that bridges multiple LLM
providers to multiple chat platforms. The core value is **simplicity**: one
config file, no database, filesystem-only persistence, and a message-bus
architecture that decouples channels from the agent loop.

### Non-Negotiable Properties

- **No database.** All state is filesystem-based (JSON, JSONL, Markdown).
- **Single config file.** `~/.nanobot/config.json` is the only config artifact.
- **Provider-agnostic.** The agent loop never imports provider-specific code.
  All provider specifics live in `providers/registry.py` and the LiteLLM
  abstraction layer.
- **Channel-agnostic.** The agent loop communicates only via `MessageBus`.
  Channels are independent modules that consume/produce bus messages.

---

## 2. Architectural Constraints

### Message Flow (invariant — do not bypass)

```
Platform → Channel.start() → bus.inbound → AgentLoop._process_message()
    → LLM call → tool execution → bus.outbound → ChannelManager → Platform
```

### Module Boundaries

| Module | Owns | Must NOT depend on |
|--------|------|--------------------|
| `agent/loop.py` | LLM interaction, tool dispatch | Any specific channel or provider impl |
| `agent/context.py` | System prompt assembly, message formatting | Session storage, bus |
| `agent/tools/` | Individual tool implementations | Channel specifics |
| `channels/` | Platform-specific I/O | Agent internals, provider specifics |
| `providers/` | LLM API abstraction | Channel specifics, agent tools |
| `bus/` | Message routing (two async queues) | Everything else |
| `config/` | Schema + loading | Runtime state |
| `session/` | JSONL persistence | Channel or provider specifics |

### Extension Points

**New LLM provider** — 2 files:
1. Add `ProviderSpec` to `providers/registry.py`
2. Add config field to `config/schema.py` `ProvidersConfig`

**New channel** — 3 files:
1. Create `channels/{name}.py` subclassing `BaseChannel`
2. Add config model to `config/schema.py` `ChannelsConfig`
3. Add init block in `channels/manager.py`

**New tool** — 2 files:
1. Create tool class in `agent/tools/` subclassing `Tool`
2. Register in `AgentLoop._register_default_tools()`

**New skill** — 1 file:
1. Create `skills/{name}/SKILL.md` with YAML frontmatter

### Patterns to Preserve

- **Pydantic v2 config** with `alias_generator=to_camel` (JSON uses camelCase,
  Python uses snake_case). Never break this convention.
- **`ProviderSpec` registry** is the single source of truth for provider
  metadata. No provider-specific logic elsewhere.
- **Session JSONL** — one JSON object per line, append-only during a turn.
  Tool results truncated to 500 chars in session storage.
- **Memory two-layer** — `MEMORY.md` (LLM-maintained facts) + `HISTORY.md`
  (append-only log). Consolidation is async and non-blocking.
- **Skills are markdown files** with YAML frontmatter. Lazy-loaded by the
  agent reading them with `read_file` tool.

---

## 3. Technology Choices & Rationale

| Choice | Rationale |
|--------|-----------|
| `litellm` | Unified API across 15+ providers without per-provider HTTP code |
| `pydantic-settings` | Type-safe config with env var override support |
| `asyncio` (no framework) | Minimal footprint; channels are independent async tasks |
| `loguru` | Zero-config structured logging with rotation |
| `hatchling` | Modern PEP 621 build with easy non-Python file inclusion |
| Filesystem persistence | No DB dependency; trivial backup/restore; human-readable |
| `json-repair` | LLM tool-call arguments are often malformed JSON |

---

## 4. Quality Gates

### Beyond Constitution Requirements

1. **Provider isolation.** Any change to a provider MUST NOT require changes
   to the agent loop or any channel.
2. **Channel isolation.** Any change to a channel MUST NOT require changes
   to the agent loop or any provider.
3. **Config backward compatibility.** New config fields MUST have defaults
   that preserve existing behavior. Never remove a config field without a
   migration in `config/loader.py`.
4. **No new runtime dependencies** without explicit approval. The dependency
   list is already large due to channel SDKs.

### Linting & Formatting

- `ruff` with rules `E`, `F`, `I`, `N`, `W` (E501 ignored)
- Line length: 100
- Target: Python 3.11

### Test Requirements

- `pytest` with `pytest-asyncio` (auto mode)
- All tests use `tmp_path` for filesystem isolation
- No network calls in unit tests — mock all HTTP/WebSocket
- New features require tests in `tests/` before merge

---

## 5. Business KPIs (Development Health)

| Metric | Target |
|--------|--------|
| Test suite passes | 100% on every merge |
| New provider integration | ≤2 files changed |
| New channel integration | ≤3 files changed |
| Config migration coverage | Every schema change has a migration path |
| Ruff violations on merge | 0 |

---

## 6. Domain-Specific Rules

### LLM Message Formatting

- System prompt is always the first message.
- Consecutive same-role messages MUST be merged before sending to strict
  providers (Minimax, DashScope). See upstream issue #1414.
- Tool results use `role: "tool"` with `tool_call_id` reference.
- `thinking_blocks` must be sanitized per-provider before forwarding.

### Security

- `allowFrom` on channels is deny-by-default. Empty list = nobody can talk
  to the bot. `["*"]` = everyone. This is validated at startup.
- `restrict_to_workspace` controls filesystem tool sandboxing.
- `exec.timeout` caps shell command execution time (default 60s).
- No secrets in config schema defaults. All API keys come from config or env.

### Concurrency

- One `AgentLoop` processes messages concurrently (one asyncio task per
  inbound message).
- `SubagentManager` handles background tasks with weak references.
- `CronService` watches `jobs.json` mtime for external modifications.
- Channels run as independent async tasks; a crash in one channel must not
  affect others.
