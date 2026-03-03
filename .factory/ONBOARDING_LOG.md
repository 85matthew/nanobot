# Factory Onboarding Log — nanobot-ai

**Date:** 2026-03-02
**Analyst:** CDO/CTO Agent (FBA)
**Repo:** github.com/85matthew/nanobot (fork of HKUDS/nanobot)

---

## 1. Analysis Process

### Phase 1: Structure Discovery

Read the full directory tree. Key observation: the codebase is remarkably
well-organized for its size. Clean separation between agent logic, channels,
providers, and config. No circular dependencies detected.

**Files read in detail:**
- `pyproject.toml` — build system, dependencies, dev tools
- `nanobot/__init__.py`, `__main__.py` — entry points
- `nanobot/agent/loop.py` — core engine (~450 lines)
- `nanobot/agent/context.py` — system prompt + message assembly (~165 lines)
- `nanobot/agent/memory.py` — two-layer memory system
- `nanobot/agent/skills.py` — skill loader
- `nanobot/agent/tools/base.py`, `registry.py` — tool abstraction
- `nanobot/bus/events.py`, `queue.py` — message bus
- `nanobot/channels/base.py`, `manager.py`, `telegram.py` — channel pattern
- `nanobot/providers/base.py`, `registry.py`, `litellm_provider.py` — provider abstraction
- `nanobot/config/schema.py`, `loader.py` — full config tree
- `nanobot/session/manager.py` — session persistence
- `nanobot/cron/service.py`, `types.py` — cron scheduling
- `nanobot/cli/commands.py` — CLI entry points
- All 15 test files in `tests/`
- `Dockerfile`, `docker-compose.yml`
- `README.md`

### Phase 2: Architecture Understanding

The architecture follows a clean message-bus pattern:

```
Channels ←→ MessageBus ←→ AgentLoop ←→ LLMProvider
                                    ←→ ToolRegistry
                                    ←→ SessionManager
```

Key design decisions I identified:
1. **No ORM/database.** All persistence is files: JSON config, JSONL sessions,
   Markdown memory. This is a deliberate minimalism choice.
2. **LiteLLM as the provider layer.** Instead of writing HTTP code for each
   provider, they use LiteLLM's unified interface and a custom registry that
   handles model name prefixing and env var setup.
3. **Raw WebSocket for Discord.** They don't use discord.py — they connect
   directly to the Discord gateway. This reduces dependencies but means more
   maintenance burden for Discord-specific features.
4. **Skills are markdown.** The skill system is just YAML-frontmatter markdown
   files that get injected into the system prompt. Simple and extensible.

### Phase 3: Upstream Issue Analysis

Checked open issues on HKUDS/nanobot. Found 30+ open issues. Evaluated the
top 7 for WP-001 suitability:

| Issue | Title | Verdict |
|-------|-------|---------|
| #1414 | Minimax rejects consecutive user messages | **Selected.** Clean bug, single-file fix, exercises core context builder, binary pass/fail, affects multiple providers |
| #1350 | send_progress/send_tool_hints config not working | Already fixed in ChannelManager._dispatch_outbound() at lines 218-222. The reporter pointed at _bus_progress but the filtering happens at the channel manager layer. |
| #1380 | Telegram groupPolicy:"mention" ignored | Good candidate but channel-specific, less architectural value |
| #1445 | Cron jobs always deliver channel messages | Requires prompt engineering, harder to test deterministically |
| #1444 | Cron job prompts from files | Good but involves schema change + migration |
| #1382 | Feishu card table count limit | Channel-specific, investigative |
| #1441 | Cron notification feedback loop | Multiple subsystems, higher risk |

### Phase 4: WP-001 Selection Rationale

Issue #1414 was selected because:
1. **Root cause is confirmed.** Lines 118-119 of `context.py` produce two
   consecutive `role: "user"` messages. This is objectively wrong.
2. **Single-file fix.** Only `nanobot/agent/context.py` needs modification.
3. **Easy to test.** Assert that no two consecutive messages share a role.
4. **High impact.** Fixes breakage on Minimax AND DashScope (issue #1344).
5. **Exercises the core.** The context builder is central to understanding
   how nanobot talks to LLMs.

---

## 2. Findings & Observations

### Strengths

- **Clean module boundaries.** Provider, channel, and agent logic are well-isolated.
- **Registry pattern.** The `ProviderSpec` registry is elegant — adding a
  provider is a data declaration, not code.
- **Test infrastructure exists.** 15 test files, good coverage of core paths.
  Tests use `tmp_path` for isolation.
- **Config system is solid.** Pydantic v2 with camelCase aliasing, env var
  overrides, and validation.

### Risks / Technical Debt

- **No conftest.py.** Common fixtures are duplicated across test files.
  A shared conftest with workspace/config fixtures would reduce boilerplate.
- **Session JSONL can grow unbounded.** The consolidation mechanism exists
  but depends on the LLM being available to summarize. If the LLM is down,
  sessions grow forever.
- **WhatsApp bridge coupling.** The Python process shells out to a Node.js
  subprocess. This is fragile — version mismatches, build failures, and
  process management are all failure modes.
- **No integration tests.** All tests are unit tests with mocked dependencies.
  There's no test that actually sends a message through the bus end-to-end.
- **Ruff config is permissive.** E501 (line length) is ignored. Some lines
  exceed 120 characters.

### Questions for Project Owner

1. **Is upstream sync desired?** Should we track HKUDS/nanobot changes, or
   is this a hard fork? This affects how we structure changes.
2. **Which channels are actually in use?** The codebase supports 10 platforms
   but the owner likely uses 1-2. We should focus testing effort accordingly.
3. **Is the WhatsApp bridge used?** If not, it's a maintenance burden we
   could drop.
4. **What's the deployment target?** Docker? systemd? Both? This affects
   what we test in CI.
5. **Are there eval suites for the LLM interactions?** The memory
   consolidation and cron prompt generation are LLM-dependent but have no
   eval framework.

---

## 3. Artifacts Produced

| Artifact | Path | Purpose |
|----------|------|---------|
| BYLAWS.md | `.factory/config/BYLAWS.md` | Project-specific strategic governance |
| CLAUDE.md | `CLAUDE.md` | Tactical coder reference |
| WP-001 | `.github/workpackages/WP-001.md` | First work package: fix #1414 |
| Onboarding Log | `.factory/ONBOARDING_LOG.md` | This document |

---

## 4. Recommended Next Work Packages

After WP-001, these are natural follow-ups in priority order:

1. **WP-002: Add conftest.py with shared fixtures.** Reduce test boilerplate,
   establish patterns for future tests.
2. **WP-003: Fix Telegram groupPolicy:mention.** Issue #1380 — exercises
   channel layer, bounded scope.
3. **WP-004: End-to-end integration test.** Send a mock message through the
   full bus pipeline and verify output. Currently no test covers this path.
4. **WP-005: CI pipeline.** GitHub Actions for pytest + ruff on PR.
