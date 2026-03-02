# CLAUDE.md — nanobot-ai

Tactical rules for working in this codebase. Read this before writing any code.

---

## Quick Start

```bash
# Install (editable, with dev + matrix deps)
pip install -e ".[dev,matrix]"

# Run tests
pytest tests/

# Lint
ruff check nanobot/

# Run the agent (needs an LLM API key in env)
ANTHROPIC_API_KEY=sk-... nanobot agent

# Run the multi-channel gateway
nanobot gateway
```

---

## Architecture Quick Reference

```
nanobot/
├── agent/                  # Core engine
│   ├── loop.py             # AgentLoop — LLM iteration + tool execution
│   ├── context.py          # ContextBuilder — system prompt assembly
│   ├── memory.py           # MemoryStore — MEMORY.md + HISTORY.md persistence
│   ├── skills.py           # SkillsLoader — bundled + custom skill loading
│   ├── subagent.py         # SubagentManager — background task spawning
│   └── tools/              # Built-in tools
│       ├── base.py         # Tool ABC (extend this for new tools)
│       ├── registry.py     # ToolRegistry — register/lookup/execute
│       ├── shell.py        # ExecTool — shell command execution
│       ├── filesystem.py   # Read/Write/Edit/ListDir file tools
│       ├── web.py          # WebFetch + WebSearch tools
│       ├── message.py      # MessageTool — send to channel
│       ├── spawn.py        # SpawnTool — launch subagents
│       ├── cron.py         # CronTool — schedule tasks
│       └── mcp.py          # MCP server tool integration
├── bus/                    # Message routing
│   ├── queue.py            # MessageBus — async inbound/outbound queues
│   └── events.py           # InboundMessage, OutboundMessage dataclasses
├── channels/               # Chat platform adapters (10 platforms)
│   ├── base.py             # BaseChannel ABC (extend this for new channels)
│   ├── manager.py          # ChannelManager — orchestrates all channels
│   ├── telegram.py         # Telegram Bot API
│   ├── discord.py          # Discord WebSocket gateway
│   ├── slack.py            # Slack Socket Mode
│   ├── feishu.py           # Feishu/Lark WebSocket
│   ├── matrix.py           # Matrix/Element with E2EE
│   ├── dingtalk.py         # DingTalk Stream
│   ├── mochat.py           # Mochat Socket.IO
│   ├── email.py            # Email IMAP/SMTP polling
│   ├── qq.py               # QQ botpy
│   └── whatsapp.py         # WhatsApp via Node.js bridge
├── config/
│   ├── schema.py           # Pydantic config models (all channel/provider configs)
│   └── loader.py           # Config file loading + validation
├── providers/              # LLM provider abstraction
│   ├── base.py             # LLMProvider ABC + LLMResponse dataclass
│   ├── registry.py         # ProviderSpec + PROVIDERS tuple (single source of truth)
│   ├── litellm_provider.py # LiteLLM-based unified provider
│   ├── custom_provider.py  # Direct OpenAI-compatible endpoint
│   ├── openai_codex_provider.py  # OAuth-based Codex
│   └── transcription.py    # Groq Whisper voice transcription
├── session/
│   └── manager.py          # SessionManager — JSONL append-only sessions
├── cron/
│   ├── service.py          # CronService — scheduled job management
│   └── types.py            # CronJob, CronSchedule dataclasses
├── heartbeat/
│   └── service.py          # HeartbeatService — periodic wake-up tasks
├── skills/                 # Bundled skills (markdown-based)
├── templates/              # Workspace scaffold templates
├── utils/
│   └── helpers.py          # Path helpers, template sync
└── cli/
    └── commands.py         # Typer CLI app (all commands)

bridge/                     # WhatsApp Node.js bridge (separate process)
tests/                      # pytest test suite
```

---

## Data Flow

```
User (Telegram/Discord/etc.)
  → Channel._handle_message()     # permission check + normalize
  → bus.publish_inbound()          # InboundMessage to queue
  → AgentLoop._dispatch()          # global processing lock
  → AgentLoop._process_message()   # build context, run LLM loop
  → AgentLoop._run_agent_loop()    # iterate: LLM call → tool exec → repeat
  → bus.publish_outbound()         # OutboundMessage to queue
  → Channel.send()                 # format + deliver to platform
```

---

## Test Commands

```bash
# Run all tests
pytest tests/

# Run a specific test file
pytest tests/test_cron_service.py -v

# Run tests matching a keyword
pytest tests/ -k "memory"

# All tests run with asyncio_mode=auto (configured in pyproject.toml)
# No need to add @pytest.mark.asyncio for individual tests
```

### Test Conventions

- Tests live in `tests/` (flat structure, no subdirectories).
- File naming: `test_<module>.py` or `test_<feature>.py`.
- Use `tmp_path` fixture for filesystem isolation.
- Mock external services — no real API calls in tests.
- Arrange-Act-Assert structure.
- Each test file is self-contained (no shared conftest.py).

---

## How To: Add a New Tool

1. Create `nanobot/agent/tools/your_tool.py`:

```python
from typing import Any
from nanobot.agent.tools.base import Tool

class YourTool(Tool):
    @property
    def name(self) -> str:
        return "your_tool"

    @property
    def description(self) -> str:
        return "What this tool does."

    @property
    def parameters(self) -> dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "param1": {"type": "string", "description": "..."},
            },
            "required": ["param1"],
        }

    async def execute(self, **kwargs: Any) -> str:
        # Implementation here
        return "result string"
```

2. Register in `AgentLoop._register_default_tools()` in `agent/loop.py`.
3. Write tests in `tests/test_your_tool.py`.

---

## How To: Add a New Channel

1. Create `nanobot/channels/your_channel.py`:

```python
from nanobot.channels.base import BaseChannel
from nanobot.bus.events import OutboundMessage

class YourChannel(BaseChannel):
    name = "your_channel"

    async def start(self) -> None:
        self._running = True
        # Connect to platform, listen for messages
        # Call self._handle_message(sender_id, chat_id, content) for each

    async def stop(self) -> None:
        self._running = False

    async def send(self, msg: OutboundMessage) -> None:
        # Format and send to platform
        pass
```

2. Add config dataclass to `config/schema.py` (follow existing pattern with `alias_generator`).
3. Register in `ChannelManager` (`channels/manager.py`).
4. Write tests in `tests/test_your_channel.py`.

---

## How To: Add a New LLM Provider

1. Add a `ProviderSpec` entry to the `PROVIDERS` tuple in `providers/registry.py`.
2. If OpenAI-compatible: set `litellm_prefix` and reuse `LiteLLMProvider`.
3. If custom protocol: create a new class extending `LLMProvider` in `providers/base.py`.
4. Add config field to `ProvidersConfig` in `config/schema.py`.

---

## Import Conventions

```python
# Standard library
from __future__ import annotations
import asyncio
import json
from pathlib import Path
from typing import TYPE_CHECKING, Any

# Third-party
from loguru import logger
from pydantic import BaseModel

# Internal — always use absolute imports from nanobot.*
from nanobot.agent.tools.base import Tool
from nanobot.bus.events import InboundMessage, OutboundMessage
from nanobot.config.schema import Config

# Type-checking only imports (avoid circular deps)
if TYPE_CHECKING:
    from nanobot.config.schema import ChannelsConfig
```

- Always use absolute imports (`from nanobot.x.y import Z`).
- Use `TYPE_CHECKING` guard for imports only needed for type hints.
- Import order: stdlib → third-party → internal (enforced by ruff `I` rules).

---

## Naming Conventions

| Entity | Convention | Example |
|---|---|---|
| Modules | `snake_case.py` | `litellm_provider.py` |
| Classes | `PascalCase` | `AgentLoop`, `MessageBus` |
| Functions/methods | `snake_case` | `_run_agent_loop`, `get_or_create` |
| Constants | `UPPER_SNAKE` | `_TOOL_RESULT_MAX_CHARS`, `PROVIDERS` |
| Config fields | `snake_case` in Python, `camelCase` in JSON | `max_tokens` / `maxTokens` |
| Test functions | `test_<description>` | `test_add_job_rejects_unknown_timezone` |
| Private methods | `_leading_underscore` | `_dispatch`, `_handle_message` |
| Channel names | `lowercase` string | `"telegram"`, `"discord"`, `"cli"` |

---

## Configuration

- Config file: `~/.nanobot/config.json`
- Pydantic schema in `config/schema.py` handles both `camelCase` (JSON) and `snake_case` (Python).
- Environment variables: provider API keys like `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc.
- Provider auto-detection: model name keywords → provider match (e.g., `"claude"` → Anthropic).

---

## Common Pitfalls

1. **Blocking I/O in async code.** Never use `requests`, `time.sleep()`, or blocking file ops in any async path. Use `httpx`, `asyncio.sleep()`, `aiofiles` or `asyncio.to_thread()`.

2. **Mutating session history.** Sessions are append-only JSONL. Never reorder, delete, or modify existing messages. Use consolidation for pruning.

3. **Bypassing the message bus.** Channels must publish through `MessageBus`, never call `AgentLoop` directly. Tools send responses via `MessageTool`, not by returning them.

4. **Forgetting `_strip_think()`.** Some models embed `<think>` blocks in content. Always strip before displaying to users.

5. **Error responses in session history.** When `finish_reason == "error"`, do NOT persist the response to session history — it poisons future LLM context (see #1303).

6. **Empty `allow_from` = deny all.** An empty `allowFrom` list blocks all senders. Use `["*"]` to allow everyone.

7. **Tool results must be strings.** `Tool.execute()` must return `str`. The agent loop doesn't handle other types.

8. **The `_processing_lock` is global.** Only one message is processed at a time per `AgentLoop` instance. Don't try to add per-session parallelism without rearchitecting this.

9. **WeakValueDictionary for consolidation locks.** `_consolidation_locks` uses `weakref.WeakValueDictionary`. Locks can be GC'd if not held — this is a known race condition (issue #1255).

10. **`ruff check` ignores E501.** Line length warnings are suppressed. Lines over 100 chars are allowed but discouraged.

---

## Linting & Formatting

```bash
# Check
ruff check nanobot/

# Auto-fix
ruff check --fix nanobot/

# Rules: E (pycodestyle), F (pyflakes), I (isort), N (pep8-naming), W (warnings)
# E501 (line too long) is ignored
# Target: Python 3.11
# Line length: 100
```

---

## Docker

```bash
# Build and run gateway
docker compose up -d nanobot-gateway

# Build image
docker build -t nanobot .

# Base image: ghcr.io/astral-sh/uv:python3.12-bookworm-slim
# Includes Node.js 20 for WhatsApp bridge
# Exposed port: 18790 (gateway)
```
