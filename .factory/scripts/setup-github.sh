#!/usr/bin/env bash
# Factory GitHub Setup — configures environment, secrets, and merge permissions
# Run this once after creating a factory with a GitHub repo.
#
# Usage: ./scripts/setup-github.sh [--env-name automated-test]
#
# Requires: gh CLI (https://cli.github.com/)

set -euo pipefail

ENV_NAME="${1:-automated-test}"
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

echo "Setting up GitHub environment '${ENV_NAME}' for ${REPO}..."

# Create environment
gh api "repos/${REPO}/environments/${ENV_NAME}" --method PUT --silent

echo "Environment '${ENV_NAME}' created."
echo ""
echo "Now add your API key as an environment secret."
echo "Choose one:"
echo "  1) Gemini (GEMINI_API_KEY)"
echo "  2) Anthropic (ANTHROPIC_API_KEY)"
echo ""
read -rp "Choice [1/2]: " choice

case "$choice" in
  1)
    echo "Enter your GEMINI_API_KEY:"
    read -rs api_key
    echo "$api_key" | gh secret set GEMINI_API_KEY --env "$ENV_NAME"
    echo "GEMINI_API_KEY set."
    ;;
  2)
    echo "Enter your ANTHROPIC_API_KEY:"
    read -rs api_key
    echo "$api_key" | gh secret set ANTHROPIC_API_KEY --env "$ENV_NAME"
    echo "ANTHROPIC_API_KEY set."
    ;;
  *)
    echo "Invalid choice. Add secrets manually:"
    echo "  gh secret set GEMINI_API_KEY --env ${ENV_NAME}"
    ;;
esac

# Set up PAT_TOKEN for merge permissions
echo ""
echo "The reviewer workflow needs a Personal Access Token (PAT) to merge PRs."
echo "GITHUB_TOKEN cannot merge PRs on private repos."
echo ""
echo "Create a fine-grained PAT at:"
echo "  GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens"
echo ""
echo "Required permissions (scoped to this repo):"
echo "  - Contents: Read and write"
echo "  - Pull requests: Read and write"
echo ""
read -rp "Enter your PAT (or press Enter to skip and add manually later): " pat_token

if [ -n "$pat_token" ]; then
  echo "$pat_token" | gh secret set PAT_TOKEN
  echo "PAT_TOKEN set as repository secret."
else
  echo "[SKIP] Add PAT_TOKEN manually later:"
  echo "  gh secret set PAT_TOKEN"
  echo "Without PAT_TOKEN, the reviewer will approve PRs but cannot merge them."
fi

# Check branch protection status
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
echo ""
echo "Checking branch protection on '${DEFAULT_BRANCH}'..."
BP_STATUS=$(gh api "repos/${REPO}/branches/${DEFAULT_BRANCH}/protection" 2>/dev/null && echo "exists" || echo "none")

if [ "$BP_STATUS" = "none" ]; then
  echo "[INFO] No branch protection rules found on '${DEFAULT_BRANCH}'."
  echo "Merges will happen immediately after reviewer approval."
  echo "For production factories, add a branch protection rule requiring status checks."
  echo ""
  echo "See: templates/scripts/setup-github.md for manual instructions."
else
  echo "Branch protection is configured on '${DEFAULT_BRANCH}'."
fi

echo ""
echo "Done. Your factory CI is configured."
echo ""
echo "Merge policy:"
echo "  - Layer 1 PRs (no integration contracts) → merged by workflow via PAT"
echo "  - Layer 2 PRs (has integration contracts) → labeled for planner review"
echo "  - PRs labeled 'needs-human-review' → human merges manually"
