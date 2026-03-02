#!/bin/bash
set -euo pipefail

echo "Bootstrapping factory: nanobot"

# Step 1: Configure GitHub environment and secrets for CI
# Run scripts/setup-github.sh to set up the automated-test environment
# and add your API key (GEMINI_API_KEY or ANTHROPIC_API_KEY).
# See scripts/setup-github.md for manual steps if gh CLI is not available.
echo "Run ./scripts/setup-github.sh to configure GitHub CI secrets."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Docker required"; exit 1; }

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from template — please fill in API keys"
    exit 1
fi

# Start the factory
docker compose up -d

echo "Factory 'nanobot' is running"
echo "   Orchestrator: http://localhost:8080"
echo "   Dashboard:    http://localhost:8501"
echo ""
echo "Getting started:"
echo "  1. Run ./scripts/setup-github.sh to configure CI"
echo "  2. Run ./scripts/start-planner.sh to start the planner agent"
echo "  3. Run ./scripts/start-coder.sh --wp WP-001 to start a coder on a task"
