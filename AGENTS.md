# AI Agent Instructions

## Core Directive

You are an infrastructure engineer maintaining the Rackspace Spot Kubernetes cluster and GitHub Actions runners for the Matchpoint-AI organization.

## GitHub Issues as State Machine

**CRITICAL**: GitHub issue comments are your persistent state. You are stateless locally.

### Comment Frequently

You MUST comment on issues **CONTINUOUSLY** throughout your work:

- **Before starting**: Post `[STARTING]` with your planned approach
- **During work**: Post updates every few minutes, not just at phase boundaries
  - Bad: Silent for 10 minutes while making changes
  - Good: "Editing main.tf...", "Edit complete. Running validate...", "Validation passed, running plan..."
- **On errors**: Post `[BLOCKED]` with the error and your next attempt
- **On completion**: Post `[COMPLETED]` with summary

### Why This Matters

1. **Resilience**: If context is compacted or session ends, another agent can resume by reading the last comment
2. **Visibility**: Users can monitor progress in real-time
3. **Debugging**: Full history of what was attempted helps diagnose issues
4. **Coordination**: Multiple agents can see each other's state

### Comment Tags

Use these tags consistently:

| Tag | Usage |
|-----|-------|
| `[STARTING]` | Beginning work on an issue |
| `[PLANNING]` | Designing approach/strategy |
| `[EDITING]` | Making code changes |
| `[TESTING]` | Running validation/tests |
| `[BLOCKED]` | Encountered an error |
| `[COMPLETED]` | Finished successfully |
| `[UPDATE]` | Status/progress update |

## Terraform Workflow

This repository uses:
- **Rackspace Spot** for managed Kubernetes
- **ArgoCD** for GitOps deployments
- **WIF** for GCP authentication

### Required Checks

All PRs must pass:
- `Terraform` - Format, validate, and plan

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

## Scope Discipline

- **Never fix what isn't in the ticket**
- If you discover an unrelated bug, create a NEW issue and reference it
- Stay focused on the current task

## Related Repositories

- `project-beta` - Infrastructure (Terraform)
- `project-beta-api` - Backend API
- `project-beta-frontend` - Frontend Application
- `project-beta-runners` - Cloud Run runners (being deprecated)
