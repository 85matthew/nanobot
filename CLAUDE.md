# CLAUDE.md — Nanobot Coder Reference

## Quick Start

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Run tests
pytest

# Lint
ruff check nanobot/ tests/

# Run the CLI
nanobot status
nanobot agent            # interactive CLI mode
nanobot gateway          # start all channels + cron + heartbeat
```

---

## Architecture at a Glance

```
nanobot/
├── agent/
│   ├── loop.py          # Core engine: LLM call → tool dispatch → response
│   ├── context.py       # System prompt + message assembly
│   ├── memory.py        # MEMORY.md (facts) + HISTORY.md (log) persistence
│   ├── skills.py        # Markdown-based skill loader (lazy, YAML frontmatter)
│   ├── subagent.py      # Background task execution
│   └── tools/           # Built-in tools (filesystem, shell, web, message, cron, mcp)
│       ├── base.py      # Tool ABC
│       └── registry.py  # ToolRegistry — dynamic registration + execution
├── bus/
│   ├── events.py        # InboundMessage, OutboundMessage dataclasses
│   └── queue.py         # MessageBus — two asyncio.Queue (inbound/outbound)
├── channels/            # Chat platform integrations (each subclasses BaseChannel)
│   ├── base.py          # BaseChannel ABC: start(), stop(), send()
│   ├── manager.py       # ChannelManager — init + outbound routing
│   ├── telegram.py      # Long-polling
│   ├── discord.py       # Raw WebSocket (not discord.py)
│   ├── slack.py         # Socket Mode
│   └── ...              # whatsapp, feishu, dingtalk, email, matrix, mochat, qq
├── providers/
│   ├── base.py          # LLMProvider ABC, LLMResponse, ToolCallRequest
│   ├── registry.py      # PROVIDERS tuple — single source of truth
│   ├── litellm_provider.py  # Main provider (wraps litellm.acompletion)
│   └── custom_provider.py   # Direct OpenAI-compatible, bypasses LiteLLM
├── config/
│   ├── schema.py        # Pydantic v2 config tree (Config root model)
│   └── loader.py        # JSON load/save + migration
├── session/
│   └── manager.py       # Session (JSONL per chat) + SessionManager
├── cron/
│   ├── service.py       # Timer-driven job scheduler
│   └── types.py         # CronJob, CronSchedule, CronPayload
├── heartbeat/
│   └── service.py       # 30-min HEARTBEAT.md polling
└── cli/
    └── commands.py      # Typer CLI: onboard, agent, gateway, cron, status
```

### Message Flow

```
Platform → Channel → bus.inbound → AgentLoop._process_message() → LLM
    → tool calls → bus.outbound → ChannelManager → Platform
```

---

## Key Files You'll Touch Most

| Task | Files |
|------|-------|
| Fix agent behavior | `agent/loop.py`, `agent/context.py` |
| Fix message formatting | `agent/context.py` (build_messages) |
| Add/fix a provider | `providers/registry.py`, `config/schema.py` |
| Add/fix a channel | `channels/{name}.py`, `channels/manager.py`, `config/schema.py` |
| Add/fix a tool | `agent/tools/{name}.py`, `agent/loop.py` (_register_default_tools) |
| Change config schema | `config/schema.py`, `config/loader.py` (migration) |

---

## How to Add a New Provider

1. Add a `ProviderSpec` entry to the `PROVIDERS` tuple in `providers/registry.py`
2. Add a `ProviderConfig` field to `ProvidersConfig` in `config/schema.py`

That's it. Env vars, model prefixing, auto-detection, and `nanobot status` all derive from the registry.

## How to Add a New Channel

1. Create `channels/{name}.py` — subclass `BaseChannel`, implement `start()`, `stop()`, `send(OutboundMessage)`
2. Add a config model in `config/schema.py` under `ChannelsConfig`
3. Add an `if self.config.channels.{name}.enabled:` block in `ChannelManager._init_channels()`

## How to Add a New Tool

1. Subclass `Tool(ABC)` in `agent/tools/{name}.py` — implement `name`, `description`, `parameters`, `execute()`
2. Register in `AgentLoop._register_default_tools()` in `agent/loop.py`

---

## Config System

- **File:** `~/.nanobot/config.json` (camelCase keys)
- **Schema:** `config/schema.py` — Pydantic v2 with `alias_generator=to_camel`
- **Env override:** `NANOBOT_` prefix, `__` as nesting delimiter
  - Example: `NANOBOT_AGENTS__DEFAULTS__MODEL=anthropic/claude-sonnet-4-20250514`
- **Key paths:**
  - `agents.defaults.model` — default LLM model
  - `agents.defaults.max_tool_iterations` — safety limit (default 40)
  - `channels.send_progress` / `channels.send_tool_hints` — streaming control
  - `tools.restrict_to_workspace` — filesystem sandboxing
  - `tools.exec.timeout` — shell command timeout (default 60s)

---

## Testing Conventions

- **Framework:** pytest + pytest-asyncio (asyncio_mode = "auto")
- **Location:** `tests/` — flat directory, one file per module/feature
- **Fixtures:** Use `tmp_path` for all filesystem state (no shared state)
- **Mocking:** `unittest.mock.patch` for config, HTTP, and file operations
- **CLI tests:** `typer.testing.CliRunner`
- **Naming:** `test_{module}_{feature}.py` → `test_{scenario}()`
- **No network:** All tests must work offline — mock external APIs

```bash
# Run all tests
pytest

# Run a specific test
pytest tests/test_commands.py -k test_match_provider

# Run with verbose output
pytest -v
```

---

## Naming & Style

- **Python:** snake_case for variables/functions, PascalCase for classes
- **Config JSON:** camelCase (Pydantic alias handles conversion)
- **Imports:** `from __future__ import annotations` in every module
- **Line length:** 100 (ruff enforced, E501 ignored)
- **Type hints:** Required on all function signatures
- **Docstrings:** Required on classes and public methods

---

## Common Pitfalls

1. **Consecutive user messages.** `ContextBuilder.build_messages()` emits two
   `role: user` messages (runtime context + actual message). Strict providers
   (Minimax, DashScope) reject this. Known issue — see upstream #1414.

2. **Config camelCase vs snake_case.** The JSON file uses camelCase but Python
   uses snake_case. Pydantic's `alias_generator=to_camel` handles this — never
   use camelCase in Python code.

3. **Provider prefix double-application.** `LiteLLMProvider._resolve_model()`
   adds prefixes. If a model name already has the prefix (e.g., `deepseek/deepseek-chat`),
   the `skip_prefixes` field prevents double-prefixing. Always check `skip_prefixes`
   when adding a provider.

4. **Session JSONL truncation.** Tool results stored in session are truncated
   to 500 chars (`AgentLoop._TOOL_RESULT_MAX_CHARS`). Don't rely on full tool
   output being in history.

5. **Channel allowFrom.** Empty `allowFrom` list = deny all. This is validated
   at startup with `SystemExit`. Use `["*"]` for open access.

6. **Whisper transcription.** Voice messages are transcribed via Groq Whisper,
   not the main LLM provider. Requires `groq.api_key` in config even if using
   a different primary provider.

7. **WhatsApp bridge.** The WhatsApp channel shells out to a Node.js process
   (`bridge/`). The bridge must be built (`npm install && npm run build` in
   `bridge/`) before WhatsApp works. Docker handles this automatically.

8. **MCP servers.** Lazily connected on first message. If an MCP server is
   unreachable, it silently fails and those tools are unavailable. Check logs.

---

## Workspace Layout (Runtime)

```
~/.nanobot/
├── config.json               # Main config (only config file)
├── workspace/
│   ├── AGENTS.md             # Agent identity/instructions (loaded into system prompt)
│   ├── SOUL.md               # Personality/voice
│   ├── USER.md               # User-specific context
│   ├── TOOLS.md              # Tool usage instructions
│   ├── HEARTBEAT.md          # Periodic task list (checked every 30 min)
│   ├── memory/
│   │   ├── MEMORY.md         # LLM-maintained long-term facts
│   │   └── HISTORY.md        # Append-only conversation log
│   ├── sessions/
│   │   └── {channel}_{chatid}.jsonl
│   └── skills/
│       └── {name}/SKILL.md
├── data/
│   └── cron/jobs.json        # Scheduled jobs
└── media/                    # Downloaded media files
```
