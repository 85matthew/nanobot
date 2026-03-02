# Manual GitHub Setup

If you don't have the `gh` CLI, follow these steps to configure the PR reviewer
and merge workflow.

## 1. Create Environment

- Go to: **Settings → Environments → New environment**
- Name: `automated-test`
- Click **Configure environment**

## 2. Add API Key Secret

- In the environment page, under **Environment secrets**
- Click **Add secret**
- Name: `GEMINI_API_KEY` (or `ANTHROPIC_API_KEY`)
- Value: your API key
- **Note:** Use SECRETS, not variables. Secrets are encrypted and masked in logs.

## 3. (Optional) Set Model Override

- Under **Environment variables** (not secrets)
- Add variable: `REVIEWER_MODEL`
- Value: e.g., `gemini/gemini-2.5-flash` or `anthropic/claude-sonnet-4-5-20250929`
- Leave empty to use auto-detection based on available API keys.

## 4. Create PAT for Merge Permissions

The default `GITHUB_TOKEN` cannot merge PRs on private repos. You need a
Personal Access Token (PAT).

**Option A: Fine-grained PAT (recommended)**

1. Go to: **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Click **Generate new token**
3. Name: `fba-merge` (or similar)
4. Resource owner: your account
5. Repository access: **Only select repositories** → select your factory repo
6. Permissions:
   - **Contents:** Read and write
   - **Pull requests:** Read and write
7. Click **Generate token** and copy the value

**Option B: Classic PAT**

1. Go to: **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token (classic)**
3. Scopes: check **`repo`** (full control of private repositories)
4. Click **Generate token** and copy the value

Then add it as a **repository secret** (not environment secret):

1. Go to: **Repo → Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Name: `PAT_TOKEN`
4. Value: paste the token
5. Click **Add secret**

**Why repository secret, not environment secret?** The merge step needs
the PAT regardless of which environment is active. Repository secrets are
available to all workflows.

**Why not GITHUB_TOKEN?** On private repos, `GITHUB_TOKEN` returns
`Resource not accessible by integration` when attempting to merge PRs.
It also cannot approve PRs owned by the token holder.

**Future:** In Phase 3, this will be replaced by a GitHub App with scoped
permissions and a separate bot identity.

## 5. (Recommended) Branch Protection

For production factories, add a branch protection rule on `main`:

- Go to: **Settings → Branches → Add branch protection rule**
- Branch name pattern: `main`
- Enable: **Require status checks to pass before merging**
- Add required checks: `review` (the PR reviewer action)
- Enable: **Require branches to be up to date before merging**

This ensures the reviewer must pass before any merge (automated or manual).

## 6. Verify

- Open a PR. The **Automated PR Review** action should trigger.
- Check the **Actions** tab for the run status.
- If it fails, check that your secret is in the `automated-test` environment
  (not at the repository level).
- If the reviewer APPROVEs a Layer 1 PR and it doesn't merge, check
  that `PAT_TOKEN` is set as a repository secret.

## Merge Policy

The factory uses a layered merge policy:

| PR Type | Label | Merge Mechanism | Gate |
|---------|-------|----------------|------|
| No integration contracts | (none) | Workflow merges via PAT | Automated reviewer APPROVE |
| Has integration contracts | `needs-planner-review` | Planner/human merges | Layer 2 review |
| `needs-human-review` label | `needs-human-review` | Human merges | Manual inspection |
| Rework cycle failed 2x | `needs-human-review` | Human merges | Auto-applied |

The automated reviewer checks the WP's `## Integration Contracts` section.
If it says "None" or "None — self-contained", the workflow merges immediately.
Otherwise, the `needs-planner-review` label is applied and the PR waits for
the planner's Layer 2 review.

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Resource not accessible by integration` | `GITHUB_TOKEN` can't merge | Add `PAT_TOKEN` repository secret (step 4) |
| `Permission denied` | Missing `pull-requests: write` | Check workflow permissions block |
| `AuthenticationError` | Wrong env or wrong secret name | Verify secret is in `automated-test` env |
| `Timeout` | LLM call took too long | Check API key quota; try a faster model |
| `404 Not Found` | Wrong repo or PR number | Check token has repo access |
| PR not merging after APPROVE | PAT_TOKEN missing or expired | Regenerate PAT, update secret |
| PR merged without checks | No branch protection | Add branch protection rule (step 5) |
