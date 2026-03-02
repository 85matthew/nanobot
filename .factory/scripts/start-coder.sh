#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v claude &> /dev/null; then
    echo "Error: 'claude' CLI not found. Install Claude Code first."
    exit 1
fi

cd "$REPO_ROOT"

MODEL="${CODER_MODEL:-claude-sonnet-4-5-20250929}"

if [ "${1:-}" = "--wp" ] && [ -n "${2:-}" ]; then
    WP_ID="$2"
    WP_FILE=$(find .github/workpackages -name "${WP_ID}-*.md" \
        -not -path "*/completed/*" | head -1)
    if [ -z "$WP_FILE" ]; then
        echo "Error: No READY work package found for $WP_ID"
        exit 1
    fi
    PROMPT="Read CLAUDE.md, then read ${WP_FILE}. Check out a new branch \
with the ${WP_ID} name. Execute the work package. Before marking COMPLETE, \
run every item in the Verification Checklist and check them off. Move the \
work package file to .github/workpackages/completed/ and include that in \
your commit. When complete, push the branch and open a pull request."
    # --dangerously-skip-permissions: required for autonomous coder — no human to confirm file writes
    exec claude --model "$MODEL" --print --dangerously-skip-permissions "$PROMPT"
else
    exec claude --model "$MODEL"
fi
