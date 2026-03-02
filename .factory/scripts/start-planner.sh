#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_FILE="$REPO_ROOT/.github/PLANNER_PROMPT.md"

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: Planner prompt not found at $PROMPT_FILE"
    echo "Run 'fba create' to generate factory files."
    exit 1
fi

if ! command -v claude &> /dev/null; then
    echo "Error: 'claude' CLI not found. Install Claude Code first."
    echo "See: https://docs.anthropic.com/claude-code"
    exit 1
fi

cd "$REPO_ROOT"
exec claude --model claude-opus-4-6 \
    --system-prompt "$(cat "$PROMPT_FILE")"
