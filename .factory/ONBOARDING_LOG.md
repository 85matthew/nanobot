# Factory Onboarding Log — nanobot-ai

**Agent:** Factory Bootstrap Agent (FBA)
**Date:** 2026-03-02
**Branch:** `clean-bootstrap`

---

## 1. Analysis Process

### Phase 1: Structure Discovery

Explored the full directory tree, identified:
- Python package at `nanobot/` (57 files, ~15K LOC total, ~4K core)
- TypeScript WhatsApp bridge at `bridge/`
- Test suite at `tests/` (15 files)
- Build system: Hatchling via `pyproject.toml`
- No CI/CD workflows in `.github/workflows/`

### Phase 2: Architecture Deep-Dive

Read 10+ source files to understand the actual code (not just filenames):
- `agent/loop.py` — Core agent processing engine. Global `_processing_lock`, LLM iteration loop with tool execution, memory consolidation.
- `agent/context.py` — Prompt builder assembling system prompt from templates, memory, skills.
- `agent/memory.py` — Two-layer memory: MEMORY.md (facts) + HISTORY.md (grep-searchable log).
- `agent/tools/base.py` — Clean Tool ABC with JSON Schema validation.
- `bus/queue.py` + `bus/events.py` — Minimal async message bus (~80 lines total).
- `channels/base.py` — BaseChannel ABC with `is_allowed()` permission model.
- `config/schema.py` — Pydantic v2 config with camelCase/snake_case alias support.
- `providers/registry.py` — ProviderSpec frozen dataclass with PROVIDERS tuple (single source of truth).
- `providers/litellm_provider.py` — LiteLLM-based unified LLM interface.
- `session/manager.py` — JSONL append-only session storage.

### Phase 3: Test Infrastructure

Read test files to understand patterns:
- `test_cron_service.py` — Clean Arrange-Act-Assert, uses `tmp_path` for isolation.
- `test_matrix_channel.py` — Largest test file (43KB), comprehensive E2EE testing.
- `pytest.ini_options` in pyproject.toml: `asyncio_mode = "auto"`, `testpaths = ["tests"]`.
- No conftest.py — each test file is self-contained.
- ruff for linting: E, F, I, N, W rules, E501 ignored.

### Phase 4: Upstream Issue Analysis

Queried HKUDS/nanobot GitHub issues via `gh` CLI:
- 45+ open issues catalogued.
- Categorized into: bugs, feature requests, support questions, architectural proposals.
- Identified 5 strong WP candidates ranked by scope, testability, and codebase coverage.

---

## 2. Key Findings

### Architecture Strengths

1. **Radical simplicity.** ~4K core LOC is genuinely impressive for an agent framework with 10 channels and 16+ providers. The code is readable and well-structured.
2. **Clean abstractions.** Tool ABC, BaseChannel ABC, LLMProvider ABC — the extension points are obvious and well-defined.
3. **Message bus decoupling.** Channels and agent loop are fully decoupled through async queues. Easy to test in isolation.
4. **Provider registry as data.** `PROVIDERS` tuple is a declarative registry — adding a provider is mostly config, not code.
5. **Append-only sessions.** JSONL storage is efficient for LLM prompt caching (avoids re-encoding unchanged history).

### Architecture Concerns

1. **Global processing lock (`_processing_lock`).** Only one message processes at a time per AgentLoop. This serializes all channels in gateway mode. Not a bug, but a scalability ceiling.
2. **WeakValueDictionary for consolidation locks.** `_consolidation_locks` can lose locks to GC while waiters exist (issue #1255). This is a real race condition.
3. **CLI module is 38KB monolith.** `cli/commands.py` handles everything — REPL, config, onboarding, status, cron, OAuth. Should be split but functional as-is.
4. **No conftest.py / shared fixtures.** Each test file reinvents fixtures. Could benefit from shared mocks for MessageBus, Provider, etc.
5. **No CI/CD.** No GitHub Actions workflows found. Testing relies on local `pytest` runs.
6. **`_bus_progress` doesn't check config.** This is issue #1350 — the WP-001 target. The CLI path correctly checks `send_progress`/`send_tool_hints`, but gateway mode skips the check.

### Technology Observations

- LiteLLM is the key dependency for provider breadth. It's well-maintained but opinionated about model naming.
- Pydantic v2 with alias generators handles JSON↔Python naming seamlessly.
- The WhatsApp bridge is a separate Node.js process connected via WebSocket — architectural outlier but necessary (Baileys is JS-only).
- MCP integration is lazy-loaded and supports both stdio and HTTP transports.

---

## 3. WP-001 Selection Rationale

Chose **issue #1350** (`send_progress`/`send_tool_hints` not working in gateway mode) because:

| Criterion | Score | Notes |
|---|---|---|
| Bounded scope | High | 5-10 line fix in one closure |
| Root cause known | High | Issue author pinpointed exact location |
| Testable | High | Mock bus, assert publish calls |
| Exercises codebase | Medium | Config loading → agent loop → bus pipeline |
| No existing PR | Yes | Clear path to contribution |
| Low risk | High | Additive guards, backward-compatible defaults |

**Runner-up candidates:**
- #1445 (cron deliver flag) — Slightly broader scope, touches tool schema
- #1380 (Telegram groupPolicy) — Good but Telegram-specific
- #1441 (cron feedback loop) — Higher complexity, needs architectural decision on message tagging
- #1255 (consolidation lock race) — Real bug but requires concurrency testing expertise

---

## 4. Questions for Project Owner

### Architecture

1. **Is the global `_processing_lock` intentional?** It serializes all message processing. Is this a deliberate simplicity choice or a known limitation that should be addressed?

2. **Session persistence strategy?** JSONL append-only is efficient but files grow unbounded if consolidation fails. Is there a garbage collection strategy?

3. **WhatsApp bridge lifecycle.** The bridge is a separate Node.js process. How is it supervised in production? Docker Compose handles it, but what about non-Docker deployments?

### Testing

4. **Test coverage target?** Current coverage appears moderate (15 test files for 57 source files). Is there a coverage target, or is the philosophy "test what matters"?

5. **Integration test strategy?** Most tests mock external services. Are there integration tests that run against real APIs (even in CI with secrets)?

### Operations

6. **CI/CD plans?** No GitHub Actions found. Is CI managed externally, or is it a gap to fill?

7. **Release process?** How are versions bumped and published to PyPI? Manual or automated?

### Governance

8. **Contribution model?** Is this primarily a single-maintainer project, or are there regular external contributors? This affects how strict governance should be.

9. **Breaking change policy?** The project is Alpha (0.1.x). Are breaking changes to config schema or tool interfaces acceptable?

---

## 5. Artifacts Produced

| Artifact | Path | Purpose |
|---|---|---|
| BYLAWS.md | `.factory/config/BYLAWS.md` | Project-specific strategic governance |
| CLAUDE.md | `CLAUDE.md` (repo root) | Tactical coder rules |
| WP-001.md | `.github/workpackages/WP-001.md` | First work package (issue #1350) |
| ONBOARDING_LOG.md | `.factory/ONBOARDING_LOG.md` | This document |

---

## 6. Recommendations

1. **Add CI.** Even a minimal `pytest` + `ruff check` GitHub Action would catch regressions.
2. **Shared test fixtures.** A `conftest.py` with mock `MessageBus`, `LLMProvider`, and `Session` would reduce test boilerplate.
3. **Split `cli/commands.py`.** 38KB is large for a single module. Consider `cli/agent.py`, `cli/config.py`, `cli/cron.py`.
4. **Fix #1255 (consolidation lock race).** This is a real concurrency bug that will bite in production under load.
5. **Document the memory consolidation algorithm.** It's a key differentiator but not well-documented outside the code.
