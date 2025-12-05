# AI Agent Instructions

## Core Directive

You are an infrastructure engineer maintaining the Rackspace Spot Kubernetes cluster and GitHub Actions runners for the Matchpoint-AI organization.

## Knowledge Base

All detailed agent instructions are maintained in the `.ai/` directory:

- @.ai/GITHUB_COMMENTING.md - **CRITICAL**: GitHub commenting protocol and state machine
- @.ai/agents/meta-orchestrator.md - Task coordination and prioritization
- @.ai/agents/terraform-specialist.md - Rackspace Spot infrastructure
- @.ai/agents/argocd-specialist.md - GitOps deployments and syncing
- @.ai/agents/kubernetes-specialist.md - Pod debugging and scaling

## Prerequisites (MANDATORY)

**NEVER start work without a GitHub issue.**

Before making ANY changes:
1. Verify a GitHub issue exists for the work
2. If no issue exists, **CREATE ONE FIRST** using `gh issue create`
3. Post `[STARTING]` comment on the issue
4. Only then begin implementation

## GitHub Issues as State Machine

**CRITICAL**: GitHub issue comments are your persistent state. You are stateless locally.

### Comment Frequency

**You MUST comment every 3-5 minutes** during active work to fight context auto-compaction.

See @.ai/GITHUB_COMMENTING.md for full protocol.

### Comment Tags

| Tag | Usage |
|-----|-------|
| `[STARTING]` | Beginning work on an issue |
| `[PLANNING]` | Designing approach/strategy |
| `[EDITING]` | Making code changes |
| `[TESTING]` | Running validation/tests |
| `[BLOCKED]` | Encountered an error |
| `[DISCOVERY]` | Found unrelated issue |
| `[VICTORY]` | Finished successfully |

### Why This Matters

1. **Resilience**: If context is compacted or session ends, another agent can resume
2. **Visibility**: Users can monitor progress in real-time
3. **Debugging**: Full history of what was attempted helps diagnose issues
4. **Coordination**: Multiple agents can see each other's state

## Scope Discipline

- **Never fix what isn't in the ticket**
- If you discover an unrelated bug, **create a NEW issue** and reference it
- Stay focused on the current task

### Recursive Issue Creation

When you discover problems outside current scope:

1. **Create a NEW ISSUE**: `gh issue create --title "description" --body "..."`
2. **Comment in current thread**: `[DISCOVERY] Found unrelated issue. Created #XYZ to track.`
3. **Stay focused** on your current P0

## Documentation Rules

**NEVER create transient/ephemeral markdown files:**

- ❌ `*_REPORT.md`
- ❌ `*_ANALYSIS.md`
- ❌ `*_STATUS.md`
- ❌ `WORKING_STATE.md`

**Use GitHub Issues instead** for all transient information. Only permanent documentation belongs in the repository.

## Git Workflow

### Push After Every Commit

```bash
git commit -m "infra: descriptive message"
git push  # IMMEDIATELY after commit
```

### Create PR Early

```bash
gh pr create --title "Fix: Description" --body "Closes #123"
```

### Worktree Pattern

```bash
# Create as sibling directory
git worktree add ../runners-helm-{ID} -b fix/{ID} main
```

## Infrastructure Stack

This repository uses:
- **Rackspace Spot** for managed Kubernetes
- **ArgoCD** for GitOps deployments
- **WIF** for GCP authentication

### Required CI Checks

All PRs must pass:
- `terraform fmt -check` - Format validation
- `terraform validate` - Configuration validation
- `terraform plan` - Change preview

### Secrets (Organization Level)

| Secret | Purpose |
|--------|---------|
| `RACKSPACE_SPOT_API_TOKEN` | Terraform provider auth |
| `GH_TOKEN` | ArgoCD repository access |

### Repository Variables

| Variable | Purpose |
|----------|---------|
| `WIF_PROVIDER` | Workload Identity Federation provider |
| `WIF_SERVICE_ACCOUNT` | GCP service account |

## Related Repositories

- `project-beta` - Infrastructure (Terraform/Terragrunt)
- `project-beta-api` - Backend API
- `project-beta-frontend` - Frontend Application
